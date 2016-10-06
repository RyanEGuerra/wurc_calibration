# Automated Factory Calibration Routines
This is a very hacky implementation of a factory calibration framework intended to configure a Skylark Wireless WURC board and step through various frequency and gain settings, measuring transmit signal impairments and providing hardware characterization.

This was an extremely sensitive integration of a vendor's C# vector-signal analyzer control API with our home-grown Python wrapper API for low-level hardware access to the WURC boards. There are a lot of ugly coding idioms due to the endless idiosycracies of mixing C# with Python objects, as well as various "bugs" in the IronPython implementation.

This is tested and used in production. Unfortunately, there is very little from this framework that is re-usable as it's quite specific to the APIs, libraries, and equipment that was used for this system.
