from concurrent import futures
import logging
import json
import psutil
import os.path
import subprocess
import re
import grpc
import rpc_pb2
import rpc_pb2_grpc
import argparse
import sys
sys.path.append('/opt/trex/current/automation/trex_control_plane/interactive')
from trex.stl.api import *
from trex_tg_lib import *


def checkIfProcessRunning(processName):
    '''
    Check if there is any running process that contains the given name processName.
    '''
    #Iterate over the all the running process
    for proc in psutil.process_iter():
        try:
            pinfo = proc.as_dict(attrs=['pid', 'name', 'status'])
            # Check if process name contains the given name string.
            if processName.lower() in pinfo['name'].lower():
                if 'zombie' in pinfo['status'].lower():
                    os.waitpid(pinfo['pid'], os.WNOHANG)
                    continue
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass

    return False

def killProcessByName(processName):
    '''
    kill all the PIDs whose name contains
    the given string processName
    '''
    #Iterate over the all the running process
    for proc in psutil.process_iter():
       try:
           pinfo = proc.as_dict(attrs=['pid', 'name'])
           # Check if process name contains the given name string.
           if processName.lower() in pinfo['name'].lower() :
               p = psutil.Process(pinfo['pid'])
               p.terminate()
       except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess) :
           return False
    return True

class Trafficgen(rpc_pb2_grpc.TrafficgenServicer):
    def isTrafficgenRunning(self, request, context):
        return rpc_pb2.TrafficgenRunning(isTrafficgenRunning=checkIfProcessRunning("binary-search"))

    def getResult(self, request, context):
        pattern = re.compile("^[0-9]+$")
        result = rpc_pb2.Result()
        try:
            with open('binary-search.json') as f:
                data = json.load(f)
            stats = data["trials"][-1]["stats"]
            for port in stats:
                if not pattern.match(port):
                    continue
                portstats = result.stats.add()
                portstats.port = port
                portstats.tx_l1_bps = stats[port]['tx_l1_bps']
                portstats.tx_l2_bps = stats[port]['tx_l2_bps']
                portstats.tx_pps = stats[port]['tx_pps']
                portstats.rx_l1_bps = stats[port]['rx_l1_bps']
                portstats.rx_l2_bps = stats[port]['rx_l2_bps']
                portstats.rx_pps = stats[port]['rx_pps']
                portstats.rx_latency_minimum = stats[port]['rx_latency_minimum']
                portstats.rx_latency_maximum = stats[port]['rx_latency_maximum']
                portstats.rx_latency_average = stats[port]['rx_latency_average']
        except:
            # return default vaule when something happens
            result = rpc_pb2.Result()
        return result

    def stopTrafficgen(self, request, context):
        return rpc_pb2.Success(success=killProcessByName("binary-search"))

    def isResultAvailable(self, request, context):
        '''
        If result file is not present or last trial is not pass, then result is not available
        '''
        try:
            with open('binary-search.json') as f:
                data = json.load(f)
            result = data["trials"][-1]["result"]
            if result == 'pass':
                return rpc_pb2.ResultAvailable(isResultAvailable=True)
            else:
                return rpc_pb2.ResultAvailable(isResultAvailable=False)
        except:
            return rpc_pb2.ResultAvailable(isResultAvailable=False)

    def startTrafficgen(self, request, context):
        # if an instance is already running, kill it first
        if checkIfProcessRunning("binary-search"):
            if not killProcessByName("binary-search"):
                return rpc_pb2.Success(success=False)
        if not request.l3:
            subprocess.Popen(["./binary-search.py", "--traffic-generator=trex-txrx",
                          "--device-pairs=%s" % request.device_pairs,
                          "--search-runtime=%d" % request.search_runtime,
                          "--validation-runtime=%d" % request.validation_runtime,
                          "--num-flows=%d" % request.num_flows,
                          "--frame-size=%d" % request.frame_size,
                          "--max-loss-pct=%f" % request.max_loss_pct,
                          "--sniff-runtime=%d" % request.sniff_runtime,
                          "--search-granularity=%f" % request.search_granularity,
                          "--rate-tolerance=50",
                          "--runtime-tolerance=50",
                          "--negative-packet-loss=fail",
                          "--rate-tolerance-failure=fail"] + binary_search_extra_args)
        else:
            subprocess.Popen(["./binary-search.py", "--traffic-generator=trex-txrx",
                          "--device-pairs=%s" % request.device_pairs,
                          "--dst-macs=%s" % request.dst_macs,
                          "--search-runtime=%d" % request.search_runtime,
                          "--validation-runtime=%d" % request.validation_runtime,
                          "--num-flows=%d" % request.num_flows,
                          "--frame-size=%d" % request.frame_size,
                          "--max-loss-pct=%f" % request.max_loss_pct,
                          "--sniff-runtime=%d" % request.sniff_runtime,
                          "--rate-tolerance=50",
                          "--runtime-tolerance=50",
                          "--negative-packet-loss=fail",
                          "--search-granularity=%f" % request.search_granularity,
                          "--rate-tolerance-failure=fail"] + binary_search_extra_args)
        if checkIfProcessRunning("binary-search"):
            return rpc_pb2.Success(success=True)
        else:
            return rpc_pb2.Success(success=False)
    
    def getMacList(self, request, context):
        macList = ""
        try:
            c = STLClient(server = 'localhost')
            c.connect()
            port_info = c.get_port_info(ports = [0, 1])
            macList = port_info[0]['hw_mac'] + ',' + port_info[1]['hw_mac']
        except TRexError as e:
            macList = ""
        finally:
            c.disconnect()
            return rpc_pb2.MacList(macList=macList)

def serve(port):
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    rpc_pb2_grpc.add_TrafficgenServicer_to_server(Trafficgen(), server)
    server.add_insecure_port('[::]:%d' %(port))
    server.start()
    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        killProcessByName("binary-search")
        server.stop(0)

if __name__ == '__main__':
    logging.basicConfig()
    parser = argparse.ArgumentParser(description='Trafficgen server')
    parser.add_argument('--port',
                        dest='port',
                        help='gRPC port',
                        default=50051,
                        type=int
                        )
    parser.add_argument('--extra-opts',
                        dest='extra_opts',
                        help='extra options for binary search',
                        default='',
                        type=str
                        )
    args = parser.parse_args()
    global binary_search_extra_args
    binary_search_extra_args = args.extra_opts.strip('\"\'').split()
    serve(args.port)
