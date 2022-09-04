import unittest
from tgen import *


class TestAddr(unittest.TestCase):
    def test_gen_ip_addr_normal(self):
        ip_gen = gen_ip_addr("1.1.1.2")
        self.assertEqual("1.1.1.2", next(ip_gen))
        self.assertEqual("1.1.1.3", next(ip_gen))
        self.assertEqual("1.1.1.4", next(ip_gen))
    
    def test_gen_ip_addr_nextbyte(self):
        ip_gen = gen_ip_addr("1.1.1.255")
        self.assertEqual("1.1.1.255", next(ip_gen))
        self.assertEqual("1.1.2.0", next(ip_gen))
        self.assertEqual("1.1.2.1", next(ip_gen))
        
    def test_get_ip_list(self):
        actual = get_ip_list("1.1.1.1,3")
        expected = ["1.1.1.1", "1.1.1.2", "1.1.1.3"]
        self.assertEqual(actual, expected)
        
    def test_gen_mac_addr(self):
        mac_gen = gen_mac_addr("00:00:00:00:00:00")
        self.assertEqual("00:00:00:00:00:00", next(mac_gen))
        self.assertEqual("00:00:00:00:00:01", next(mac_gen))
    
    def test_gen_mac_addr_nextbyte(self):
        mac_gen = gen_mac_addr("00:00:00:00:00:ff")
        self.assertEqual("00:00:00:00:00:ff", next(mac_gen))
        self.assertEqual("00:00:00:00:01:00", next(mac_gen))
    
    def test_get_mac_list(self):
        actual = get_mac_list("00:00:00:00:ff:ff,3")
        expected = ["00:00:00:00:ff:ff", "00:00:00:01:00:00", "00:00:00:01:00:01"]
        self.assertEqual(actual, expected)
    
    def test_get_port_list(self):
        actual = get_port_list("3000,3")
        expected = [3000, 3001, 3002]
        self.assertEqual(actual, expected)