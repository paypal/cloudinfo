#!/usr/bin/env python
 
import argparse
import socket
import time
 
 
CARBON_SERVER = '<carbon_server>'
CARBON_PORT = 2003
 
parser = argparse.ArgumentParser()
parser.add_argument('metric_path')
parser.add_argument('value')
#parser.add_argument('timestamp')
args = parser.parse_args()


if __name__ == '__main__':
   timestamp = int(time.time())
   message = '%s %s %d\n' % (args.metric_path, args.value, timestamp)
 
   print 'sending message:\n%s' % message
   sock = socket.socket()
   sock.connect((CARBON_SERVER, CARBON_PORT))
   sock.sendall(message)
   sock.close()
