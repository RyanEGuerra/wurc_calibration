'''
wsdnode.py
  Python wrapper and useful functions for sending/parsing terminal input
  to/from a connected usb serial device of the WSD or WARP type.
  
  Please see class comments below for instructions on how to use this class.
  
  This class encapsulates the SCG class and uses it to modify calibration values
  The SCG class was developed and written totally by Naren.
  
  Copyright 2013 Ryan E. Guerra

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  
  === Change Log ===
0.50 - added RxIQ calibration as menu option at the same time as I updated the MicroBlaze
       code to accept those commands. This is not backwards-compatible with older MicroBlaze
       versions. Also removed static search paths for IronPython. I found that WinPython
       is a far superior and self-contained installation of Python for Windows 7, so we'll
       require it's use in the future. Otherwise, installing NumPy and IPY paths/DLLs is a mess.
       
0.72 - forget what other updates were. This revision adds a lot of error checking and library
       checking in preparation for pushing this code to the students. It should be feature
       complete with no known bugs to the main wrapper code.
       
0.73 - Increased the range of the RX IQ Imbalance permissable values, and added Coarse and
       Fine calibration for Rx IQ Imbalance. REG
       
0.74 - Changed the way that calibration files are loaded to correspond to firmware versions
       2.24 and later of the WSD firmware. This makes RXLOFT values frequency-dependent.
       Also removed the "< " from returned characters to make them look cleaner in the python
       terminal. This also makes the JSON block parseable. REG
       
1.0  - Stable version release across all platforms. REG

1.01 - Updated to Apache License. REG
    
Created on Aug 30, 2013
@author: me@ryaneguerra.com
@author: nanand@rice.edu
@lastedit: January 26, 2013

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
'''

# explicitly set WSDNode as the only object available from this library
__all__ = ['WSDNode']

# NOTE: the following imports are sloppy. Sorry.

#  Relies on PySerial: http://pyserial.sourceforge.net/pyserial.html
# imports for WSDNode
import serial, glob, re, os
    
# imports for SCG
import math, ctypes

# imports for debug
import sys, traceback

# version number: made RXLOFT values frequency-dependant with new calibration file format.
WSDNODE_VERSION = '1.01'

# Print system/version information for helping debug across platforms
print "===== WSDNode Debug Info =========================================="
print "Python Ver : " + sys.version
print "OS String  : " + os.name
print "PySerial   : " + serial.VERSION
print "WSDNode Ver: " + WSDNODE_VERSION

# we found that there were some serious problems with older versions of the driver
# on linux.
if float(serial.VERSION) < 2.6 and os.name != 'nt':
    print "ERROR: your version of PySerial is out of date. Please update to the "
    print "       most recent version with the following terminal command:"
    print
    print "       $ sudo pip install pyserial --upgrade"
    print
    print "       Thanks to Pablo Salvador, this script will now exit..."
    sys.exit("Bad driver version.")

# Some global variables and constants.
WARP_PROMPT = "WARP$"
WSD_PROMPT = "wss$"
DISCOVER_TIMEOUT = 0.001
NORMAL_TIMEOUT = 0.05

# Location to search for calibration files
wsd_calibration_files_glob = './cal_files/*.csv'

WARP_TYPE       = 'WARP'
WSD_TYPE        = 'WSD'
UNKNOWN_TYPE    = '????'

class WSDNode(object):
    '''
    This is currently designed to wrap a single-WSD WARP kit, or a single WSD device
    directly. You can initialize a new wrapper with no knowledge of the connected
    devices and the constructor will enumerate all USB serial devices and allow the
    user to select amongst them. Example:

    >>> from WSDWARPWrapper import WSDNode
    >>> Node_1 = WSDNode(None, None)

    Alternately, you can pass default serial string and node type ('WARP', 'WSD') to
    attach the new Node object to that target device. In this case, the constructor will
    try to find that exact device amongst the connected serial devices. If it
    cannot find the device, then it ignores the passed arguments and proceeds with
    enumeration and user-selection as above.
    NOTE: WSD serial codes are 5-digits long and represented in UPPER-CASE hexadecimal.
    Example:

    >>> from WSDWARPWrapper import WSDNode
    >>> Node_2 = WSDNode('0001A', 'WARP')
    '''
    version = WSDNODE_VERSION
    dev = None                  # actual serial device object
    dev_ttyname = None            # the os name for this device
    dev_type = None             # WSD or WARP type
    dev_serial = None           # initialized WSD serial number
    cal_state = 'TXLOFT'        # use '5' to cycle through modes: TXLOFT, TXIQ, RXIQ
    passthrough_scg = False     # toggle LOFT or IQ mult

    # globals to keep track of current mag/phase state
    # magDB         = -0.7 : 0.01 : 0.7
    # phaseDeg     = -7 : 0.1 : 7
    mag_db    = 0
    phase_deg = 0
    rx_mag_db = 0
    rx_phase_deg = 0

    
    def list_serial_ports(self):
        '''
        Cross-platform serial port enumeration function.
        Taken from user Thomas on stackoverflow
        http://stackoverflow.com/questions/12090503/listing-available-com-ports-with-python
        '''
        # Windows
        if os.name == 'nt':
            # Scan for available ports.
            available = []
            for i in range(100):
                try:
                    s = serial.Serial(i)
                    # Modified because IronPython doesn't enumerate
                    # COM ports the same way that CPython does; stemming
                    # from the underlying .NET difference. This should
                    # work for both. REG
                    # http://stackoverflow.com/questions/3024760/pyserial-and-ironpython-get-strange-error
                    available.append(s.portstr)
                    s.close()
                except (serial.SerialException, IndexError) as e:
                    # CPython throws this error when you try to open a COM port that
                    # doesn't exist.
                    #print "COM%d: %s" % (i, e)
                    pass
                except Exception as e:
                    # Not sure what causes this error, perhaps one of the Xilinx programmers 
                    # doesn't respond nicely to serial commands. In either case, becasue of debugging,
                    # I want to see the exception message.
                    print "Unexpected serial error on COM%d: " % i, sys.exc_info()[0]
                    print "\"%s\""% e
            return available
        elif os.name == 'posix':
            # Mac / Linux
            try:
                from serial.tools import list_ports
                return [port[0] for port in list_ports.comports() + glob.glob('/dev/ttyUSB*')]
            except Exception as e:
                # I've never had a problem here, but I'd like the script to handle this gracefully on Unices.
                print "Unexpected serial error: ", sys.exc_info()[0]
        else:
            print "ERROR: unhandled OS string discovered: %s" % os.name
            return None      

    def __init__(self, user_serial, user_type):
        '''
        Constructor for the WSD device wrapper. This is currently designed to wrap a single-WSD
        WARP kit, or a single WSD device directly. You can initialize a new wrapper with
        no knowledge of the connected devices and the constructor will enumerate all
        and allow the user to select amongst them. Example:
    
        >>> from WSDWARPWrapper import WSDNode
        >>> Node_1 = WSDNode(None, None)
    
        Or, you can pass default serial string and node type ('WARP', 'WSD') to attach
        the new Node object to that target device. In this case, the constructor will
        try to find that exact device amongst the connected serial devices. If it
        cannot find the device, then it ignores the passed arguments and proceeds with
        enumeration and user-selection as above.
        NOTE: WSD serial codes are 5-digits long and represented in UPPER-CASE hexadecimal.
        Example:
    
        >>> from WSDWARPWrapper import WSDNode
        >>> Node_2 = WSDNode('0001A', 'WARP')
    
        \param user_serial - a 5-digit upper-case HEX string of the device's search serial number
        \param user_type - a string specifying the serial device type: 'WSD' or 'WARP'
        '''
        # get a list of WSD/WARP devices attached to this host
        # this is how they enumerate for me on Mac OS X 10.8.4
        # They appear as either:
        # /dev/tty.usbmodem* or /dev/tty.usbserial*
        tty_array = self.list_serial_ports() #glob.glob('/dev/tty.usb*')
        if tty_array == []:
            print "ERROR: No serial WSD or WARP devices detected!"
            return
        # Discover connected devices and try to connect to them and
        # retrieve their serial number. This is a bit easier than trying
        # to parse USB system data from different OS-es.
        count = -1
        serials_array = []
        types_array = []
        dev_array = []
        print "=== Initializing WSDWARP Wrapper v%s ===" % self.version
        sel_ind = None
        if user_serial and user_type:
            # Try to find the passed serial number in the list of connected devices
            # If not found, then the serial number will be ignored and a list of devices 
            # will be presented for the user to select from.
            for device_path in tty_array:
                count += 1
                # Check to see if the device_path is even a serial device_path
                try:
                    dev = serial.Serial(device_path, 115200, timeout=DISCOVER_TIMEOUT)
                    dev_array.append(dev)
                except:
                    # can't connect to device
                    serials_array.append('%s' % ('XXXXX'))
                    types_array.append(UNKNOWN_TYPE)
                    dev_array.append(None)
                    continue
                # If the device opened, try to identify the device type
                dev_type = WSDNode.getDeviceType(dev)
                if dev_type == UNKNOWN_TYPE:
                    # can't infer a device type from its output
                    serials_array.append('%s' % ('XXXXX'))
                    types_array.append(UNKNOWN_TYPE)
                    continue
                # Try to get the device_path ID: the WSD serial #, or the serial
                # of the WSD attached to the WARP device_path
                dev_id = WSDNode.getDeviceID(dev, dev_type)
                if dev_id == None:
                    # can't get a device id number from its output
                    serials_array.append('%s' % ('XXXXX'))
                    types_array.append(dev_type)
                    continue
                else:
                    serials_array.append(dev_id)
                    types_array.append(dev_type)
                # This is a good WSD Node device. Check to see if it's the one the user wants...
                if (user_serial == dev_id) and (user_type == dev_type):
    #                    print "DEBUG TEST : [%s] [%s] == [%s] [%s]" % (user_serial, user_type, dev_id, dev_type)
                    sel_ind = count
                    break
                else:
                    pass
    #                    print "DEBUG MATCH: [%s] [%s] != [%s] [%s]" % (user_serial, user_type, dev_id, dev_type)
            # We weren't able to find a match in the list of connected devices.
            if sel_ind == None:
                print "ERROR: No device matching Serial: %s, Type: %s was found!" % (user_serial, user_type)
                user_serial = None
                user_type = None
            else:
                print "Found %s device with serial %s. Okay." % (types_array[sel_ind], serials_array[sel_ind])
        if user_serial == None or user_type == None or user_serial == [] or user_type == []:
            # The user will select the serial number of this device from
            # a list. Print the list and get user input...
            # Reset arrays and counters
            count = -1
            serials_array = []
            types_array = []
            dev_array = []
            if tty_array == None:
                print "ERROR: No available COM devices found!"
                print "       This is unusual, as normally several virtual COM ports are"
                print "       available on every system. A good idea would be to check your"
                print "       version of Python and PySerial driver above."
                print "       1. Please send a screenshot of the debug output printed when"
                print "          this script first runs to me@ryaneguerra.com"
                print "       2. Check USB cable connections to your WARP/WSD boards."
                print "       3. Try updating your version of PySerial drivers to the latest version."
                print
                sys.exit("Aborting...")
            # Enumerate available TTY devices; this includes
            for device_path in tty_array:
    #            print "DEBUG: trying to connect to [%s]" % device_path
                count += 1
                # Check to see if the device_path is even a serial device_path
                try:
                    dev = serial.Serial(device_path, 115200, timeout=DISCOVER_TIMEOUT)
                    dev_array.append(dev)
                except:
                    # can't connect to device
                    print '(%d) ERROR WITH DEVICE   %s (if COM#, not reliable)' % (count, device_path)
                    serials_array.append('%s' % ('XXXXX'))
                    types_array.append(UNKNOWN_TYPE)
                    dev_array.append(None)
                    continue
                # If the device opened, try to identify the device type
                dev_type = WSDNode.getDeviceType(dev)
                if dev_type == UNKNOWN_TYPE:
                    # can't infer a device type from its output
                    print '(%d) UNKNOWN DEVICE TYPE %s' % (count, device_path)
                    serials_array.append('%s' % ('XXXXX'))
                    types_array.append(UNKNOWN_TYPE)
                    continue
                # Try to get the device_path ID: the WSD serial #, or the serial
                # of the WSD attached to the WARP device_path
                dev_id = WSDNode.getDeviceID(dev, dev_type)
                if dev_id == None:
                    # can't get a device id number from its output
                    print '(%d) %s BAD DEVICE SERIAL  %s' % (count, dev_type, device_path)
                    serials_array.append('%s' % ('XXXXX'))
                    types_array.append(dev_type)
                    continue
                else:
                    print '(%d) %s %s %s' % (count, dev_type, dev_id, device_path)
                    serials_array.append(dev_id)
                    types_array.append(dev_type)
#             for kk in range(0, len(tty_array)):
#                 print "DEBUG %d : %s | %s | %s" % (kk, tty_array[kk], serials_array[kk], types_array[kk])
            # Let the user select to appropriate device from the list
            sel_ind = None
            while (1):
                print 'Select a device from the above options...'
                # Get user input, but allow for a keyboard interrupt gracefully (e.g. they ctrl+c)
                try:
                    user_string = raw_input()
                except KeyboardInterrupt:
                    for open_dev in dev_array:
                        open_dev.close()
                    sys.exit("Input Cancelled")
                # Test the user input for validity
                try:
                    if not user_string or user_string == '':
                        raise ValueError
                    # Try string => int conversion
                    sel_ind = int(user_string)
                    if ( sel_ind > len(tty_array) - 1 or sel_ind < 0 ):
                        raise ValueError
                    print 'You selected: %d' % sel_ind
                except:
                    print 'ERROR: Please choose a valid #'
                    continue
                break
        # finalize this wrapper's associated parameters & device
        self.dev = dev_array[sel_ind]
        self.dev_ttyname = tty_array[sel_ind]
        self.dev_serial = serials_array[sel_ind]
        self.dev_type = types_array[sel_ind]
#         print "DEBUG: serial={%s}, type={%s}, dev={%s}" % (self.dev_serial, self.dev_type, self.dev_ttyname)
        
        # Close all other open serial devices.
        for ind in range(0, len(dev_array)):
            # don't close the chosen device!
            if ind == sel_ind:
                continue
            # but DO close all the rest
            try:
                if dev_array[ind] != None:
                    dev_array[ind].close()
            except:
                print "WARN: problem closing %s" % tty_array[ind]
        # now that we've discovered our serial device, lengthen the
        # serial timeout parameter to make it more lenient.
        self.dev.timeout = NORMAL_TIMEOUT
        

    @classmethod
    def Create(cls):
        '''
        Factory method for the WSDNode class allows cross-platform instantiation
        Primarily for .NET and IronPython, which currently makes me want to gouge
        my eyes out. 
        
        >>> dev = WSDNode.Create()
        
        The above call is the same as:
        
        >>> dev = WSDNode(None, None)
        '''
        return cls(None, None) 
        

    def readToPrompt(self, isVerbose):
        '''
        Accessor to the static method that automatically passes the object
        pointer.
        '''
        # The 
        WSDNode.readDevToPrompt(self.dev, self.dev_type, isVerbose)


    def write(self, word, isVerbose):
        '''
        Write the passed string to the connected device's UART terminal
        '''
    #        if isVerbose:
    #            print "  %s" % (word)
        try:
            self.dev.write(bytes(word))
        except:
            print "ERROR: WSD write failed! [%s]" % word
            pass
    

    def CS_DevType(self):
        '''
        Accessor methods for local fields used for C# harmony.
        '''
        return self.dev_type
    def CS_DevSerial(self):
        '''
        Accessor methods for local fields used for C# harmony.
        '''
        return self.dev_serial

    def autocalExecute(self, cmd_str):
        '''
        I had to make this function because passing booleans between C# and Python
        wasn't working properly and I couldn't figure out how to make it work. I
        figure that during autocalibration, we want a complete record of all commands
        and responses anyway, so we should always execute command verbosely anyway.
        '''
        self.executeString(cmd_str, True)
         
    def executeString(self, my_cmd, isVerbose):
        ''' 
        Execute the command string on the associated terminal
        device. This handles checking if the command is pass-
        through [0-9] or not and appends the appropriate 
        line return, if necessary.
        '''
        regex = re.compile('[0-9]')
        if len(my_cmd) == 1 and regex.search(my_cmd):
            # The user input a 0-9 character
            if my_cmd == '5':
                # Toggle the quick-write mode
                if self.cal_state == 'TXLOFT':
                    print "--> Calibration Quick-write: Tx IQ Imbalance Mode"
                    self.cal_state = 'TXIQ'
                elif self.cal_state == 'TXIQ':
                    print "--> Calibration Quick-write: Rx IQ Imbalance Mode - Coarse"
                    self.cal_state = 'RXIQ_Coarse'
                elif self.cal_state == 'RXIQ_Coarse':
                    print "--> Calibration Quick-write: Rx IQ Imbalance Mode - Fine"
                    self.cal_state = 'RXIQ_Fine'
                elif self.cal_state == 'RXIQ_Fine':
                    print "--> Calibration Quick-write: Tx LOFT Mode"
                    self.cal_state = 'TXLOFT'
                else:
                    print "ERROR: Unknown Calibration State = " + self.cal_state
                return 0
                
                if self.passthrough_scg:
                    print "--> Calibration Quick-write Mode: LOFT Mode"
                    self.passthrough_scg = False
                else:
                    print "--> Calibration Quick-write Mode: SCG Mode"
                    self.passthrough_scg = True
                return 0
            # Otherwise the user input a number to change some values.
            else:
                if self.cal_state == 'TXLOFT':
                    # Just pass through the 1-4, 6-9 character;
                    # The WSD device will handle LOFT settings    
                    self.write(my_cmd, isVerbose)
                elif self.cal_state == 'TXIQ' or self.cal_state == 'RXIQ_Coarse' or self.cal_state == 'RXIQ_Fine':
                    # Modify the IQ Cal settings
                    isVerbose = False
                    if self.dev_type == WSD_TYPE:
                        print "ERROR: Can't modify IQ Cal values directly on a WSD board!"
                        print "       We required NumPy libraries to perform the trig"
                        print "       operations for calculating mag/phase corrections,"
                        print "       but most importantly: the pre-distortion is applied"
                        print "       at the baseband processor, thus you must connect directly"
                        print "       to a WARP board running a supported design to set IQ Cal values"
                        return -1
                    # We have the numbers [6,9] adjust the current
                    # magDB         = -0.7 : 0.01 : 0.7
                    # phaseDeg     = -7 : 0.1 : 7
                    isOOB = False
                    if my_cmd == '6':
                        # Decrement magdB
                        if self.cal_state == 'TXIQ':
                            if self.mag_db - 0.01 < -0.7:
                                isOOB = True
                            else:
                                self.mag_db -= 0.01
                        elif self.cal_state == 'RXIQ_Coarse' or self.cal_state == 'RXIQ_Fine':
                            if self.rx_mag_db - 0.01 < -1.01:
                                isOOB = True
                            else:
                                self.rx_mag_db -= 0.01
                        else:
                            print "ERROR: bad cal state!"
                            return -1
                    elif my_cmd == '7':
                        # Increment magdB
                        if self.cal_state == 'TXIQ':
                            if self.mag_db + 0.01 > 0.7:
                                isOOB = True
                            else:
                                self.mag_db += 0.01
                        elif self.cal_state == 'RXIQ_Coarse' or self.cal_state == 'RXIQ_Fine':
                            if self.rx_mag_db + 0.01 > 1.01:
                                isOOB = True
                            else:
                                self.rx_mag_db += 0.01
                        else:
                            print "ERROR: bad cal state!"
                            return -1
                    elif my_cmd == '8':
                        # Decrement phaseDeg
                        if self.cal_state == 'TXIQ':
                            if self.phase_deg - 0.1 < -7:
                                isOOB = True
                            else:
                                self.phase_deg -= 0.1
                        elif self.cal_state == 'RXIQ_Coarse':
                            if self.rx_phase_deg - 0.1 < -100:
                                isOOB = True
                            else:
                                self.rx_phase_deg -= 1
                        elif self.cal_state == 'RXIQ_Fine':
                            if self.rx_phase_deg - 0.1 < -100:
                                isOOB = True
                            else:
                                self.rx_phase_deg -= 0.1
                        else:
                            print "ERROR: bad cal state!"
                            return -1
                    elif my_cmd == '9':
                        # Increment phaseDeg
                        if self.cal_state == 'TXIQ':
                            if self.phase_deg + 0.1 > 7:
                                isOOB = True
                            else:
                                self.phase_deg += 0.1
                        elif self.cal_state == 'RXIQ_Coarse':
                            if self.rx_phase_deg + 0.1 > 100:
                                isOOB = True
                            else:
                                self.rx_phase_deg += 1
                        elif self.cal_state == 'RXIQ_Fine':
                            if self.rx_phase_deg + 0.1 > 100:
                                isOOB = True
                            else:
                                self.rx_phase_deg += 0.1
                        else:
                            print "ERROR: bad cal state!"
                            return -1
                    # Check bounds.
                    if isOOB:
                        print "ERROR: Maximum IQ Cal Mag or Phase Reached!"
                        return -1
                    # Update SCG values on the WARP Node
                    try:
                        if self.cal_state == 'TXIQ':
                            self.setTxIQCompensation(self.mag_db, self.phase_deg)
                        elif self.cal_state == 'RXIQ_Coarse' or self.cal_state == 'RXIQ_Fine' :
                            self.setRxIQCompensation(self.rx_mag_db, self.rx_phase_deg)
                    except Exception:
                        print "ERROR: Problem with setting IQ Cal values. Potentially helpful msg below:"
                        print "NOTE:  This operation requires NumPy. This is installed with WinPython by default."
                        print "NOTE:  Do not try to set IQ Cal via keys using IronPython on Windows."
                        print "       NumPy is terribly broken in this case... Use C# or parent script to"
                        print "       perform the {mag, phase} -> {smult, cmult, gmult} calculation"
                        print "       and then use the alternate WARPWSDWrapper function:"
                        print "       >>> node.setSCGDirect(smult, cmult, gmult)"
                        print "       The original exception message is below:"
                        print
                        print traceback.format_exc()
#                    Res = SCG.mp2scg(self.mag_db, self.phase_deg)
#                    print "IQ Cal Mag = %1.2f, Phase = %1.1f" % (self.mag_db, self.phase_deg)
#    #                    print "IQ Regs S = %s, C = %s, G = %s" % (Res.sinmult_hex, Res.cosmult_hex, Res.gain_hex)
#    #                    print "        S = %d, C = %d, G = %d" % (int(Res.sinmult_hex, 16), int(Res.cosmult_hex, 16), int(Res.gain_hex, 16))
#                    self.write('ws%d\r' % int(Res.sinmult_hex, 16), isVerbose)
#                    self.readToPrompt(isVerbose)
#                    self.write('wc%d\r' % int(Res.cosmult_hex, 16), isVerbose)
#                    self.readToPrompt(isVerbose)
#                    self.write('wg%d\r' % int(Res.gain_hex, 16), isVerbose)
#                    # The last readToPrompt is not necessary b/c the main function calls it.
        elif len(my_cmd) == 1 and ord(my_cmd) == 27:
            # The ESCAPE character is being passed. Don't append
            # RET or else this will throw things into disarray.
            self.write(my_cmd, isVerbose)
            if  self.readToPrompt(isVerbose):
                # the function returns 1 on timeout...
                print "ERROR: Timed out command: %s" % my_cmd
            # Clear any other input waiting in the queue.
            # This should deal with cases where multiple prompts
            # are printed or not properly handled--if the user
            # presses ESC, all Tx/Rx buffers are cleared!
            self.dev.flushInput()
            return
        else:
            # This is just a normal command. Add the 
            # trailing carriage return to force the WSD
            # terminal to process the opcode:command tuple
    #            print "DEBUG: writing [%s] + RET" % my_cmd
            self.write(my_cmd + '\r', isVerbose)
        # eat returned lines until you see the appropriate
        # command prompt indicating that the command is done.
        if  self.readToPrompt(isVerbose):
            # the function returns 1 on timeout...
            print "ERROR: Timed out command: %s" % my_cmd
        #RYANFIXME

    def setSCGDirect(self, smult, cmult, gmult):
        '''
        Used to workaround the problem using Numpy in IronPython. The calculations for
        S, C, G are done in C# and the results and input here.
        '''
        Res = SCG(smult, cmult, gmult)
        #print "IQ Cal Mag = %1.2f, Phase = %1.1f" % (self.mag_db, self.phase_deg)
        print "IQ Regs S = %s, C = %s, G = %s" % (Res.sinmult_hex, Res.cosmult_hex, Res.gain_hex)
        print "        S = %d, C = %d, G = %d" % (int(Res.sinmult_hex, 16), int(Res.cosmult_hex, 16), int(Res.gain_hex, 16))
        self.write('ws%d\r' % int(Res.sinmult_hex, 16), True)
        self.readToPrompt(False)
        self.write('wc%d\r' % int(Res.cosmult_hex, 16), True)
        self.readToPrompt(False)
        self.write('wg%d\r' % int(Res.gain_hex, 16), True)
        self.readToPrompt(False)
        return Res


    def setTxIQCompensation(self, magnitude_dB, phase_deg):
        '''
        Calculate and set the TRANSMIT phase/magnitude of the associated WSD board. Not intended for multi-radio
        setups. This function depends on the NumPy library, which appears to be broken with IronPython for
        Windows, but worked with the standard WinPython installation which installs NumPy by default. 
        Use WinPython and you will not regret it.
        '''
        # only WARP nodes can set shared registers. (okay, not strictly true, but we
        # didn't write an API for it)
        if self.dev_type == WSD_TYPE:
            print "ERROR: can't set Tx IQ Compensation on WSD device yet. Try directly connected to WARP..."
            return
        # Update SCG values stored locally (so quick-commands interact nicely with external apps)
        self.mag_db = magnitude_dB
        self.phase_deg = phase_deg
        Res = SCG.mp2scg(self.mag_db, self.phase_deg)
        print "TxIQ Cal Mag = %1.2f, Phase = %1.1f" % (self.mag_db, self.phase_deg)
        #print "IQ Regs S = %s, C = %s, G = %s" % (Res.sinmult_hex, Res.cosmult_hex, Res.gain_hex)
        #print "        S = %d, C = %d, G = %d" % (int(Res.sinmult_hex, 16), int(Res.cosmult_hex, 16), int(Res.gain_hex, 16))
        self.write('ws%d\r' % int(Res.sinmult_hex, 16), False)
        self.readToPrompt(False)
        self.write('wc%d\r' % int(Res.cosmult_hex, 16), False)
        self.readToPrompt(False)
        self.write('wg%d\r' % int(Res.gain_hex, 16), False)
        # The last readToPrompt is not necessary b/c the main function calls it.


    def setRxIQCompensation(self, magnitude_dB, phase_deg):
        '''
        Calculate and set the RECEIVE phase/magnitude of the associated WSD board.
        '''
        # only WARP nodes can set shared registers. (okay, not strictly true, but we
        # didn't write an API for it)
        if self.dev_type == WSD_TYPE:
            print "ERROR: can't set Tx IQ Compensation on WSD device yet. Try directly connected to WARP..."
            return
        # Update SCG values stored locally (so quick-commands interact nicely with external apps)
        self.rx_mag_db = magnitude_dB
        self.rx_phase_deg = phase_deg
        Res = SCG.mp2scg(self.rx_mag_db, self.rx_phase_deg)
        print "RxIQ Cal Mag = %1.2f, Phase = %1.1f" % (self.rx_mag_db, self.rx_phase_deg)
        #print "IQ Regs S = %s, C = %s, G = %s" % (Res.sinmult_hex, Res.cosmult_hex, Res.gain_hex)
        #print "        S = %d, C = %d, G = %d" % (int(Res.sinmult_hex, 16), int(Res.cosmult_hex, 16), int(Res.gain_hex, 16))
        self.write('wd%d\r' % int(Res.sinmult_hex, 16), False)
        self.readToPrompt(False)
        self.write('wv%d\r' % int(Res.cosmult_hex, 16), False)
        self.readToPrompt(False)
        self.write('wh%d\r' % int(Res.gain_hex, 16), False)
        # The last readToPrompt is not necessary b/c the main function calls it.

    def clearTerminalBuffer(self):
        '''
        Clear any characters in the device terminal buffer by sending an escape
        character and waiting for the return terminal prompt. This make sure
        that later commands don't have any junk preceding them.
        '''
        # Clear the buffers by sending ESCAPE ('\x1B')
        # Each terminal (WARP or WSD) responds by clearing
        # the command buffer and printing a prompt to the terminal
        self.write('\x1B', False)
        self.readToPrompt(False)

    def readline(self):
        '''
        Read a line from the serial device's UART. This is an external call to
        make the test code look cleaner.
        '''
        return self.dev.readline()

    @staticmethod
    def readDevToPrompt(ser, dev_type, isVerbose):
        '''
        Reads to the WARP$ or wsd$ terminal prompt depending on the
        type of device attached. This is a safe function: it will time
        out and print a return value if no prompt is returned after 
        a timeout period.
    
        param: ser - the open serial device
        param: isVerbose - boolean indicating whether or not all the 
               output until the prompt should actually be displayed.
        '''
        count = 0
        # save the last line; sometimes a readLine() grabs only
        # half of a line before returning, so we search for prompt
        # strings in the current line AS WELL AS the current line
        # concatenated with the previous line.
        lastlastLine = "" #for debug
        lastLine = ""
        while (1):
            line = ser.readline()
            # Print any errors encountered in the command
            # Print each received line if verbose
            if (isVerbose == True and line) or ('!' in line):
                print '%s' % line.replace("\r", "").rstrip()
            # wait for the expected prompt depending on device type
            if dev_type == WARP_TYPE and (WARP_PROMPT in line or WARP_PROMPT in (lastLine + line)):
                return 0
            elif dev_type == WSD_TYPE and (WSD_PROMPT in line or WSD_PROMPT in (lastLine + line)):
                return 0
            # Timeout code
            if not line:
                count += 1
                if count > 1000:
                    print "ERROR: readToPrompt() timed out!"
                    print "Last Lines: [%s][%s]" % (lastlastLine, lastLine)
                    return 1
            else:
                count = 0
                # save the last-received line
                lastlastLine = lastLine
                lastLine = line.strip()
            

    def getPacketCounts(self):
        '''
        Query and parse the returned packet counter values for a WARP serial
        device. This returns (Tx, Rx) counts, or (0, 0) if it's not a WARP
        type
    
        Returns (TX_count, RX_Count) tuple; this is (-1,-1) if an error occurs
        '''
        if self.dev_type != WARP_TYPE:
            print "ERROR: Querying a non-WARP device for packet counts!"
            return (-1, -1)
        # Clear command buffer--just in case.
        ESC_CH = chr(27)
        self.write(ESC_CH, False)
        self.readToPrompt(False)
        # Query packet counters
        self.write('gc\r', False)
        regex_result = None
        count = 0
        last_line = None    # to handle case where serial read cuts line in middle
        while (1):
            line = self.dev.readline()
            # Check if this is the line containing packet count information
            # Or (elif), if it's the second half of a line read cut in the middle
            if 'Packet Count' in line:
                regex_result = re.findall('[0-9]+', line)
                if len(regex_result) != 2:
                    # save the current line, sometimes readline() gets
                    # half-lines
                    last_line = line
                else:
                    # return regex results after clearing buffer
                    break
            elif last_line:
                # The previous line must have been a half-line
                # Try again, appending the last read line to current line
                line = last_line + line
                regex_result = re.findall('[0-9]+', line)
                if len(regex_result) != 2:
                    # Give up... badness happened
                    last_line = None
                else:
                    # return regex results after clearing buffer
                    break
            # Timeout code
            if not line:
                count += 1
                if count > 2000:
                    print "ERROR: getPacketCounts() timed out!"
                    return (-1, -1)
            else:
                count = 0
        # Clear the incoming buffer by eating all lines to the prompt.
        self.readToPrompt(False)
        # great! return the packet counts
        return (regex_result[0], regex_result[1])
    
    @staticmethod
    def getDeviceID(dev, dev_type):
        '''
        Queries the device for its WSD id number, either directly or of
        the attched WSD daughtercard via passthrough serial.
        ''' 
        dev_id = None
        assert(dev != None)
        assert(dev_type != None)
        # Query the attached device for its WSD's information
        if dev_type == WARP_TYPE:
            dev.write(bytes('Q0i\r'))
        elif dev_type == WSD_TYPE:
            dev.write(bytes('i\r'))
        else:
            print "ERROR: Unknown device type: %s" % (dev_type)
            return None
        count = 0
        while (1):
            line = dev.readline()
            # DEBUG
            #print '< %s' % (line.replace("\r", "").rstrip())
            if 'Serial' in line:
                # look for any number of Numerical digits, followed
                # by any number of hexadecimal digits.
                # The return value of re.search() is a MatchObject,
                # which is True if a match was found
                res = re.search('[0-9]+[a-fA-F0-9]*', line)
                if res:
                    dev_id = res.group(0)
                else:
                    print "ERROR: no serial number found in string: \"%s\"" % (line)
            # If we see the appropriate prompt, then we know that the serial
            # device is done printing: we don't need to wait for timeout
            if dev_type == WSD_TYPE and WSD_PROMPT in line:
                break
            if dev_type == WARP_TYPE and WARP_PROMPT in line:
                break 
            # Timeout just in case
            if not line:
                count += 1
                if count > 50:
                    break
            else:
                count = 0
        # this could return None
        return dev_id


    def close(self):
        '''
        Function to gracefully close the attached serial device and delete
        references in preparation for the object to be cleaned up.
        '''
        self.dev.close()
        self.dev_type = None
        self.dev_serial = None

    def loadCalibrationTable(self):
        '''
        Function for discovering and loading a local calibration file
        into the attached WSD device.
        
        The global variable 'wsd_calibration_files_glob' determines where
        we look for a calibration file for this WSD device. Since I don't have
        an elegant way to calibrate a WARP board with multiple daughter cards
        attached, this function does NOT allow calibration via the passthrough
        interface. Also, it was found that passing that many UART commands at
        once sometimes caused trouble.
        
        The function will try to match the serial number of this WSD with the
        first matching calibration file and load the table to the WSD.
        
        '''
        # At this time, there are a couple issues with pass-through calibration
        # 1. it doesn't scale with multiple connected WSD radios.
        # 2. there is a bug where the passthrough UART seems to get stuck with
        #    a large volume of commands. This should be checked out in general,
        #    but is officially a TODO.
        if self.dev_type != WSD_TYPE:
            print "ERROR: Pass-through calibration is not supported at this time."
            print "       Please connect a cable directly to the desired WSD"
            print "       board's micro-USB port and open a serial terminal"
            print "       to that device directly."
            print "       Aborting..."
            return
        # Try to auto-discover the calibration file of this WSD device.
        print "This node's serial number: %s" % self.dev_serial
        config_arr = glob.glob(wsd_calibration_files_glob)
        config_file = None
        # Prompt the user to confirm the filename
        for f in config_arr:
    #            print "DEBUG: checking [%s] for [%s]" %(f, self.dev_serial)
            res = re.search(self.dev_serial, f)
            if res:
                print "Matching configuration file found: %s" % (f)
                res = raw_input("Is this correct, [y/N]? ")
                if res == 'Y' or res == 'y':
                    config_file = f
                    break
                else:
                    pass
        # Either the user rejected all matching filenames or no matches were
        # found. Print and exit.
        if not config_file:
            print "No matching configuration file found for serial %s." % self.dev_serial
            print "This may be because they don't exist or are in the wrong place."
            print "Place configuration files in the same folder as this script."
            print "Aborting..."
            return

        # Function used a lot for string formatting, so it's now a helper function here
        def stripHexPrefix(hex_str):
            '''
            Strips the '0x' prefix from a hex string for parsing purposes
            '''
            tokens = hex_str.split('x')
            return tokens[1]

        band = None
        state = None
        index = 0
        with open(config_file, 'rb') as f:
            line = f.readline()
            while line:
                # strip any trailing newline character here to allow readline
                # to return a '\n' on a blank line and not trigger EOF
                line = line.rstrip()
                (line, sep, comment) = line.partition('#')
                if not line:
                    # this ended up being a blank line when the comments were
                    # removed. So skip it.
                    line = f.readline()
                    continue
    #                print "--> %s" % line
                
                if re.search('@@BAND', line):
                    # "@@BAND 01"
                    tokens = line.split()
                    band = int(tokens[1])
                    print "==> Found Band %s" % band
                elif re.search('@@TX_LOFT', line):
                    state = 'TXLOFT'
                    index = 0
                elif re.search('@@RX_LOFT', line):
                    state = 'RXLOFT'
                    index = 0
                elif re.search('@@TX_IQ_IMBALANCE', line):
                    state = 'TX_IQ'
                    index = 0
                elif re.search('@@RX_IQ_IMBALANCE', line):
                    state = 'RX_IQ'
                    index = 0
                else:
                    if state == None or band == None:
                        print "ERROR: Malformed calibration file! Aborting..."
        #                return
                    sloppytokens = line.split(',')
                    tokens = []
                    # Remove the whitespace from the tokens
                    for tok in sloppytokens:
                        tokens.append(tok.strip())
                    # ===========================================
                    if state == 'TX_IQ':
                        try:
                            assert len(tokens) == 4
                        except:
                            print "Malformed TXLOFT Cal Entry:"
                            print " {{%s}}" %line
                            return
                        cmd_str = "c%1d%02X%s%s%s0" % (band, \
                                                     index, \
                                                     stripHexPrefix(tokens[1]), \
                                                     stripHexPrefix(tokens[2]), \
                                                     stripHexPrefix(tokens[3]))
                        print "==> %2d Sending: %s" % (index, cmd_str)
                        if self.dev_type == WSD_TYPE:
                            self.executeString(cmd_str, False)
                            # Naren's calibration files only contain calibration values for actual WiFi
                            # channels. This means for WiFi channels 1-11, 14. The WiFi channels between
                            # 11 and 14 are not provided. To simplify the firmware code, all calibration
                            # points are assumed to be at constant intervals. Thus, we repeat the last
                            # calibration value twice to fill out the frequency table.
                            if band == 1 and index == 13:
                                cmd_str = "c%1d%02X%s%s%s0" % (band, \
                                                     index + 1, \
                                                     stripHexPrefix(tokens[1]), \
                                                     stripHexPrefix(tokens[2]), \
                                                     stripHexPrefix(tokens[3]))
                                print "==> %2d Sending: %s (REPEAT)" % (index + 1, cmd_str)
                                self.executeString(cmd_str, False)
                                cmd_str = "c%1d%02X%s%s%s0" % (band, \
                                                     index + 2, \
                                                     stripHexPrefix(tokens[1]), \
                                                     stripHexPrefix(tokens[2]), \
                                                     stripHexPrefix(tokens[3]))
                                print "==> %2d Sending: %s (REPEAT)" % (index + 2, cmd_str)
                                self.executeString(cmd_str, False)
                        elif self.dev_type == WARP_TYPE:
                            self.executeString("Q0" + cmd_str, False)
                        else:
                            print "ERROR: bad type! Aborting..."
                            return
                        index += 1
                    # ===========================================
                    elif state == 'RX_IQ':
                        try:
                            assert len(tokens) == 4
                        except:
                            print "Malformed RXIQ Cal Entry:"
                            print " {{%s}}" %line
                            return
                        cmd_str = "c%1d%02X%s%s%s1" % (band, \
                                                     index, \
                                                     stripHexPrefix(tokens[1]), \
                                                     stripHexPrefix(tokens[2]), \
                                                     stripHexPrefix(tokens[3]))
                        print "==> %2d Sending: %s" % (index, cmd_str)
                        if self.dev_type == WSD_TYPE:
                            self.executeString(cmd_str, False)
                            # Naren's calibration files only contain calibration values for actual WiFi
                            # channels. This means for WiFi channels 1-11, 14. The WiFi channels between
                            # 11 and 14 are not provided. To simplify the firmware code, all calibration
                            # points are assumed to be at constant intervals. Thus, we repeat the last
                            # calibration value twice to fill out the frequency table.
                            if band == 1 and index == 13:
                                cmd_str = "c%1d%02X%s%s%s1" % (band, \
                                                             index + 1, \
                                                             stripHexPrefix(tokens[1]), \
                                                             stripHexPrefix(tokens[2]), \
                                                             stripHexPrefix(tokens[3]))
                                print "==> %2d Sending: %s (REPEAT)" % (index + 1, cmd_str)
                                self.executeString(cmd_str, False)
                                cmd_str = "c%1d%02X%s%s%s1" % (band, \
                                                             index + 2, \
                                                             stripHexPrefix(tokens[1]), \
                                                             stripHexPrefix(tokens[2]), \
                                                             stripHexPrefix(tokens[3]))
                                print "==> %2d Sending: %s (REPEAT)" % (index + 2, cmd_str)
                                self.executeString(cmd_str, False)
                        elif self.dev_type == WARP_TYPE:
                            self.executeString("Q0" + cmd_str, False)
                        else:
                            print "ERROR: bad type! Aborting..."
                            return
                        index += 1
                    # ===========================================
                    elif state == 'TXLOFT':
                        try:
                            assert len(tokens) == 3
                        except:
                            print "Malformed TXLOFT Cal Entry:"
                            print " {{%s}}" %line
                            return
                        cmd_str = "c%1d%02X%s%s0" % (band, \
                                                   index, \
                                                   stripHexPrefix(tokens[1]), \
                                                   stripHexPrefix(tokens[2]))
                        print "==> %2d Sending: %s" % (index, cmd_str)
                        if self.dev_type == WSD_TYPE:
                            self.executeString(cmd_str, False)
                        elif self.dev_type == WARP_TYPE:
                            self.executeString("Q0" + cmd_str, False)
                        else:
                            print "ERROR: bad type! Aborting..."
                            return
                        index += 1
                    # ===========================================
                    elif state == 'RXLOFT':
                        try:
                            assert len(tokens) == 3
                        except:
                            print "Malformed TXLOFT Cal Entry:"
                            print " {{%s}}" %line
                            return
                        cmd_str = "c%1d%02X%s%s1" % (band, \
                                                index, \
                                                stripHexPrefix(tokens[1]), \
                                                stripHexPrefix(tokens[2]))
                        print "==> %2d Sending: %s" % (index, cmd_str)
                        if self.dev_type == WSD_TYPE:
                            self.executeString(cmd_str, False)
                            # Naren's calibration files only contain calibration values for actual WiFi
                            # channels. This means for WiFi channels 1-11, 14. The WiFi channels between
                            # 11 and 14 are not provided. To simplify the firmware code, all calibration
                            # points are assumed to be at constant intervals. Thus, we repeat the last
                            # calibration value twice to fill out the frequency table.
                            if band == 1 and index == 13:
                                cmd_str = "c%1d%02X%s%s1" % (band, \
                                                index + 1, \
                                                stripHexPrefix(tokens[1]), \
                                                stripHexPrefix(tokens[2]))
                                print "==> %2d Sending: %s (REPEAT)" % (index + 1, cmd_str)
                                self.executeString(cmd_str, False)
                                cmd_str = "c%1d%02X%s%s1" % (band, \
                                                index + 2, \
                                                stripHexPrefix(tokens[1]), \
                                                stripHexPrefix(tokens[2]))
                                print "==> %2d Sending: %s (REPEAT)" % (index + 2, cmd_str)
                                self.executeString(cmd_str, False)
                        elif self.dev_type == WARP_TYPE:
                            self.executeString("Q0" + cmd_str, False)
                        else:
                            print "ERROR: bad type! Aborting..."
                            return
                        index += 1
                    # ===========================================
                    else:
                        print "ERROR: bad state %s. Aborting..." % state
        #                return
                # read next line for next loop iteration
                line = f.readline()
        print "Done loading calibration file! Committing calibration table..."
        if self.dev_type == WSD_TYPE:
            self.executeString('s', False)
        elif self.dev_type == WARP_TYPE:
            self.executeString("Q0s", False)
        else:
            print "ERROR: bad type! Aborting..."
            return
        
        print "Calibration Load Finished."

    @staticmethod        
    def getDeviceType(dev):
        '''
        Queries the passed serial device to determine if it's a WSD or WARP device
        This depends on the used of the volo_term.h library, which clears the buffers
        when sent an escape character and prints a prompt unique to the given
        device.
    
        param: dev - the serial device to query
    
        returns: WARP_TYPE, WSD_TYPE, or UNKNOWN_TYPE
        '''
        assert(dev != None)
        wsdPromptObserved = False
        # Clear the buffers by sending ESCAPE (ASCII_ESC)
        # Each terminal (WARP or WSD) responds by clearing
        # the command buffer and printing a prompt to the terminal
        ch = chr(27)
        try:
            dev.write(bytes(ch))
        except Exception as e:
            # at least on windows device I found that sometime this was thrown
            print e
            return UNKNOWN_TYPE
            
        # try to read lines until you see a "$wsd" or "$WARP"
        count = 0 
        while(1):
            line = dev.readline()
            # Allow up to 50 blank lines before assuming the instruction
            # is completed or there is no response coming.
            if not line:
                count += 1
                if count > 50:
                    break
            else:
                count = 0
            # If we see a prompt of either type, we know immediately that
            # this is that type of terminal
            if WARP_PROMPT in line:
                return WARP_TYPE
            if WSD_PROMPT in line:
                wsdPromptObserved = True
        # The above timed out; assume no WARP prompt is coming. Did we
        # see a WSD prompt?
        if wsdPromptObserved:
            return WSD_TYPE
        # If we reach this point, nothing was returned after writing to
        # serial device, so we indicate this is an unknown device.
        return UNKNOWN_TYPE
        
class SCG(object):
    '''
    ** Magnitude and Phase Calibration Ranges **
    magDB         = -0.7 : 0.01 : 0.7
    phaseDeg     = -7   :  0.1 : 7
    '''
    sinmult_hex = None
    cosmult_hex = None
    gain_hex = None
    sinmult = None
    cosmult = None
    gain = None
    version = '1.0'


    def __init__(self, s,c,g):
        '''
        Constructor for the SCG class
        '''
        self.sinmult = s
        self.cosmult = c
        self.gain = g
        self.sinmult_hex = SCG.float2hex(s)
        self.cosmult_hex = SCG.float2hex(c)
        self.gain_hex = SCG.float2hex(g)

    @staticmethod
    def mp2scg(magnitude_dB, phase_deg):
        '''
        Converts Magnitude and Phase to hex representations of s,c,g
        Takes magnitudea and phase as arguments and returns a scgHex Object
        with converted values.
        == Magnitude and Phase Calibration Ranges ==
          magDB        = -0.7 : 0.01 : 0.7
          phaseDeg     = -7   :  0.1 : 7
        '''
        import numpy as np
        magDB = np.float32(magnitude_dB/10.0)
        phaseDeg = np.float32(phase_deg)
        #magDB = magIN/10.0
        #phaseDeg = phaseIN
    
        #ten_f32 = np.float32(10.0)
        one_f32 = np.float32(1.0)
   
        # Backoff to prevent Fixed 12_11 overflow
        #    (make this a #define?  can you do that in python?)
        ADJ_GAIN = np.float32(4.8828125e-4)
   
        # Convert to Linear Magnitude and Radians
        #phaseRad = np.multiply(phaseDeg, np.float32(1.7453292e-02), dtype=np.float32)
        phaseRad = np.multiply(np.float32(phaseDeg), np.float32(1.7453292e-02))
   
        #phaseRad = np.multiply(phaseDeg, 1.7453292e-02)
        #magLin = np.power(10.0,magDB,dtype=np.float32)
        magLin = np.power(np.float32(10.0), np.float32(magDB))
    
        # Compute Sine and Cosine Multipliers
        #smult = np.multiply(magLin, np.sin(phaseRad, dtype=np.float32), dtype=np.float32)
        #cmult = np.multiply(magLin, np.cos(phaseRad, dtype=np.float32), dtype=np.float32)
        smult = np.multiply(np.float32(magLin), np.float32(np.sin(np.float32(phaseRad))))
        cmult = np.multiply(np.float32(magLin), np.float32(np.cos(np.float32(phaseRad))))
   
        # Gain Calculation   
        #gain = np.subtract( np.divide(one_f32, np.maximum(np.add(one_f32,smult,dtype=np.float32), cmult, dtype=np.float32), dtype=np.float32), ADJ_GAIN, dtype=np.float32)
        intermed_1 = np.float32( np.add(one_f32, np.float32(smult)) )
        intermed_2 = np.float32( np.maximum(intermed_1, cmult) )
        intermed_3 = np.float32( np.divide(one_f32, intermed_2) )
        gain = np.float32( np.subtract( intermed_3, ADJ_GAIN) )
        #gain = np.divide(one_f32, np.subtract(np.maximum(np.add(one_f32,smult), cmult), ADJ_GAIN,dtype=np.float32))
      
        # Store Hex String representations
        return SCG( np.float32(smult), np.float32(cmult), np.float32(gain) )
        #return float2hex(smult), float2hex(cmult), float2hex(gain)

    @staticmethod
    def mp2scg_old(magDB, phaseDeg):
        '''
        Converts Magnitude and Phase to hex representations of s,c,g
        Takes magnitudea and phase as arguments and returns a scgHex Object
        with converted values.
        == Magnitude and Phase Calibration Ranges ==
          magDB        = -0.7 : 0.01 : 0.7
          phaseDeg     = -7   :  0.1 : 7
        '''
        # Bounds and precision checking
        assert magDB >= -0.7 and magDB <= 0.7
        assert phaseDeg >= -7 and phaseDeg <= 7
        # Note: testing has shown that this doesn't work with floats at all
        # because of the storage precision issues, statements like this can't work,
        # because in some cases phaseDeg % 0.1 = 0.1 - epsilon ==> DOH!
    #        try:
    #            assert abs(magDB % 0.01) < 0.001
    #            assert abs(phaseDeg % 0.1) < 0.001
    #        except AssertionError:
    #            print "ERROR: increment size mag_db %f, phase_deg %f" % (magDB % 0.01, phaseDeg % 0.1)
        # Backoff to prevent Fixed 12_11 overflow 
        #    (make this a #define?  can you do that in python?)
        ADJ_GAIN = 4.8828125e-4
        
        # Convert to Linear Magnitude and Radians
        magLin   = math.pow(10.0,magDB/10.0)
        phaseRad = math.radians(phaseDeg)
        
        # Compute Sine and Cosine Multipliers
        smult = magLin * math.sin(phaseRad)
        cmult = magLin * math.cos(phaseRad)
        
        # Gain Calculation
        gain =  1.0/(max(1.0+smult, cmult) - ADJ_GAIN)
        
        # Store Hex String representations 
        return SCG(smult,cmult,gain)
    

    @staticmethod
    def float2hex(fl):
        '''
        # Utility function to convert single precision float to hex string
        # --- Hex string ** does not ** have preceeding 0x or succeeding L as usually
        #    printed by the python hex() function
        '''
        # Python Float to C Float Pointer
        fP = ctypes.pointer(ctypes.c_float(fl))     
        # C Float Pointer to C Uint pointer       
        uP = ctypes.cast(fP, ctypes.POINTER(ctypes.c_uint)) 
        # Dereference C Uint pointer, convert to Hex String
        hV = '%08X' % (uP.contents.value)                         
        return hV
