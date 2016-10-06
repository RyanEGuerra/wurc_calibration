'''
Created on Sep 8, 2013

wsd_term.py

A simple script to open a new python terminal to any attached WSD
serial device. This works with both the WARP USB UART and the WSD
USB UART devices, and will automatically adjust depending on which
one you choose to attach to.

Please note that since this is a Python wrapper to the WSD/WARP
terminals, this simply send each command string typed in the
terminal to the attached device when the user presses "Return"

You can send an "Escape" character by pressing the escape key and
then pressing "Return." The output will look like crap, but it
will actually work.

Requires PySerial: http://pyserial.sourceforge.net/pyserial.html

Example: >>> python wsd_term.py

Revision History
=====

0.4 - cleared buffer when first connecting, so that commands don't
      lag behind screen printouts. REG 02/24/2014


@author: me@ryaneguerra.com

The MIT License (MIT)
=====================

Copyright (c) 2014 Ryan E. Guerra

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
'''
from wsdnode import WSDNode
from signal import signal, SIGINT
import sys, os, re

VERSION = "0.4"

print "======================= Python Terminal v" + VERSION + " ======================"

# OSX, Linux
if os.name == 'posix':
    import termios, fcntl, tty
    
# Windows
if os.name == 'nt':
    import msvcrt
    print
    print "WARNING: On Windows, we've found that msvcrt.getwch() doesn't handle \"DEL\" keystrokes."
    print "         What this means is that you can't delete terminal input in this script."
    print "         If you have fat fingers, you can press \"ESC\" at any time to clear the buffers."
    print "         Or you can debug this issue and email a fix to me@ryaneguerra.com, your choice."
    print

Node = None

# This allows the user to halt and close the serial
# device at any time by typing CTRL+C to send the 
# interrupt signal SIGINT to the running script process.
def sigint_received(signum, frame):
    if Node:
        Node.close()
    print "Goodbye..."
    exit(0)
# register SIGINT callback
signal(SIGINT, sigint_received)


class _Getch:
    '''
    This guy is awesome: http://love-python.blogspot.com/2010/03/getch-in-python-get-single-character.html
    '''
    def __init__(self):
        if os.name == 'posix':
            self.impl = _GetchUnix()
        elif os.name == 'nt':
            self.impl = _GetchWindows()
        else:
            print "ERROR: unknown os.name = %s" % os.name        
            
    def __call__(self):
        return self.impl()

class _GetchUnix:
    '''
    This class definition is different than that at the link, but that's
    because it's a known-working version for MacOS.
    '''
    def __init__(self):
        pass

    def __call__(self):
        fd = sys.stdin.fileno()

        oldterm = termios.tcgetattr(fd)
        newattr = termios.tcgetattr(fd)
        newattr[3] = newattr[3] & ~termios.ICANON & ~termios.ECHO
        termios.tcsetattr(fd, termios.TCSANOW, newattr)

        oldflags = fcntl.fcntl(fd, fcntl.F_GETFL)
        fcntl.fcntl(fd, fcntl.F_SETFL, oldflags | os.O_NONBLOCK)

        try:        
            while 1:            
                try:
                    c = sys.stdin.read(1)
                    break
                except IOError: pass
        finally:
            termios.tcsetattr(fd, termios.TCSAFLUSH, oldterm)
            fcntl.fcntl(fd, fcntl.F_SETFL, oldflags)
        return c

class _GetchWindows:
    '''
    Class for getting a single char from the terminal in Windows
    '''
    def __init__(self):
        pass
                
    def __call__(self):
        return msvcrt.getwch()

class wsd_term():
    '''
    Open a generic WSD Node device. This will try to
    enumerate all connected WSD devices and allow the
    user to interact with it.
    '''
    Node = None
    
    def __init__(self):
        '''
        Instantiate a terminal, you will have to select an attached WSD or WARP
        device by serial number.
        '''
        self.Node = WSDNode.Create()
    
    def run(self):
        '''
        Start the interactive terminal with the WSD/WARP device.
        This provides a terminal interface on any OS.
        '''
        # Clear device buffer by sending an ASCII ESC character to the device.
        # This should dump the WSD splash owl to the screen.
        self.Node.executeString(str(unichr(27)), True)
        
        # Forever pass user input through to the attached USB serial device.
        # To exit the terminal, you must press CTRL+C.
        print "===================== Python Terminal v" + VERSION + " ===================="
        print "Type: \"docal()\" in the terminal to load a calibration file, or"
        print "      \"quit()\" to exit the terminal."
        regex = re.compile('[0-9]')
        getch = _Getch()
        while (1):
            user_string = ""
            sys.stdout.write('>>> ')
            while (1):
                ch = getch()
                if ch == '\000':
                    print "DEBUG: SPECIAL CHAR"
                if ch == '\n' or ch == '\r':
                    # User initiate command execution
                    sys.stdout.write('\n')
                    # the command "docal" is a special string
                    if user_string == 'docal()':
                        self.Node.loadCalibrationTable()
                    elif user_string == 'quit()':
                        sigint_received(0,0)
                    else:
                        self.Node.executeString(user_string, True)
                #            print "DEBUG: execute [%s]" % user_string
                    break
                if ord(ch) == 127:  #DEL
                    # delete key removes last character
                    if len(user_string) > 0:
                        sys.stdout.write('\b \b')
                        user_string = user_string[0:len(user_string)-1]
                    continue
                if ord(ch) == 27:   #ESC
                    # Clear device buffer
                    sys.stdout.write('\n')
                    self.Node.executeString(ch, True)
                    break
                # echo back the printed character and add to buffers
                sys.stdout.write(ch)
                user_string += ch
                if len(user_string) == 1 and regex.search(user_string):
                    # Execute immediately - this is a quick-code
                    sys.stdout.write('\n')
                    self.Node.executeString(user_string, True)
                #            print "DEBUG: execute [%s]" % user_string
                    break
       
       
# run the terminal
print ""
print "Running interactive terminal..."
term = wsd_term()
term.run()