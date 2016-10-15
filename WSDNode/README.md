# WSDNodeWrapper - Python Wrapper for WURC/WARPv3 Nodes

This is currently designed to wrap a single-WSD WARP kit, or a single WSD device
directly. You can initialize a new wrapper with no knowledge of the connected
devices and the constructor will enumerate all USB serial devices and allow the
user to select amongst them.
Example:

```python
from WSDWARPWrapper import WSDNode
Node_1 = WSDNode(None, None)
```

Alternately, you can pass default serial string and node type ('WARP', 'WSD') to
attach the new Node object to that target device. In this case, the constructor will
try to find that exact device amongst the connected serial devices. If it
cannot find the device, then it ignores the passed arguments and proceeds with
enumeration and user-selection as above. WSD serial codes are 5-digits long and represented
in UPPER-CASE hexadecimal.
Example:

```python
from WSDWARPWrapper import WSDNode
Node_2 = WSDNode('0001A', 'WARP')
```

This wrapper will discover either an attached WARPv3 USB/UART port, or the direct WURC USB/UART port.

# wsd_term.py

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

Requires PySerial: [http://pyserial.sourceforge.net/pyserial.html]

Example:
```bash
$ python wsd_term.py
```
