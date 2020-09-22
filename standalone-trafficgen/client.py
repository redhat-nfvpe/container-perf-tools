from __future__ import print_function
import logging
import grpc
import rpc_pb2
import rpc_pb2_grpc
import time
import argparse

def actionGetResult(stub):
    response = stub.isResultAvailable(rpc_pb2.IsResultAvailableParams())
    if not response.isResultAvailable:
        print("test result not avalable.")
        return
    response = stub.getResult(rpc_pb2.GetResultParams())
    print("port %s rx_pps: %.2f" %(response.stats[0].port, response.stats[0].rx_pps))
    print("port %s rx_pps: %.2f" %(response.stats[1].port, response.stats[1].rx_pps))

def actionStartTrafficgen(args, stub):
    response = stub.startTrafficgen(rpc_pb2.BinarySearchParams(
            search_runtime=args.search_runtime,
            validation_runtime=args.validation_runtime,
            num_flows=args.num_flows,
            device_pairs=args.device_pairs,
            frame_size=args.frame_size,
            max_loss_pct=args.max_loss_pct,
            sniff_runtime=args.sniff_runtime
            ))
    print("start trafficgen: %s" % ("success" if response.success else "fail"))

def actionStopTrafficgen(stub):
    response = stub.stopTrafficgen(rpc_pb2.StopTrafficgenParams())
    print("stop trafficgen: %s" % ("success" if response.success else "fail"))

def actionStatus(stub):
    response = stub.isTrafficgenRunning(rpc_pb2.IsTrafficgenRunningParams())
    print("trafficgen is currently %s running" %("" if response.isTrafficgenRunning else "not"))
    response = stub.isResultAvailable(rpc_pb2.IsResultAvailableParams())
    print("test result is avalable: %s" % ("yes" if response.isResultAvailable else "no"))

def run(args):
    with grpc.insecure_channel("%s:%d" % (args.server_addr, args.server_port)) as channel:
        stub = rpc_pb2_grpc.TrafficgenStub(channel)
        if args.action == "start":
            actionStartTrafficgen(args, stub)
        elif args.action == "stop":
            actionStopTrafficgen(stub)
        elif args.action == "status":
            actionStatus(stub)
        elif args.action == "get-result":
            actionGetResult(stub)
        else:
            print("invalid action: %s" %(args.action))

if __name__ == '__main__':
    logging.basicConfig()
    parser = argparse.ArgumentParser(description='Trafficgen client')
    parser.add_argument('action',
                        help='specify what action the server will take',
                        choices=['start', 'stop', 'status', 'get-result']
                        )
    parser.add_argument('--frame-size',
                        dest='frame_size',
                        help='L2 frame size in bytes',
                        default=64,
                        type=int
                        )
    parser.add_argument('--num-flows',
                        dest='num_flows',
                        help='number of unique network flows',
                        default=1,
                        type = int,
                        )
    parser.add_argument('--search-runtime',
                        dest='search_runtime',
                        default=10,
                        help='test duration in seconds for each search iteration',
                        type=int
                        )
    parser.add_argument('--validation-runtime',
                        dest='validation_runtime',
                        help='test duration in seconds during final validation',
                        default=30,
                        type = int
                        )
    parser.add_argument('--sniff-runtime',
                        dest='sniff_runtime',
                        help='test duration in seconds during sniff phase',
                        default = 0,
                        type = int
                        )
    parser.add_argument('--max-loss-pct',
                        dest='max_loss_pct',
                        help='maximum percentage of packet loss',
                        default=0.002,
                        type = float
                        )
    parser.add_argument('--device-pairs',
                        dest='device_pairs',
                        help='list of device pairs in the form A:B[,C:D][,E:F][,...]',
                        default="0:1"
                        )
    parser.add_argument('--server-addr',
                        dest='server_addr',
                        help='trafficgen server address',
                        default='localhost'
                        )
    parser.add_argument('--server-port',
                        dest='server_port',
                        help='trafficgen server port',
                        default=50051,
                        type = int
                        )
    args = parser.parse_args()
    run(args)
