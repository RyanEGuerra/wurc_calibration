// WSDAutoCal.cs
// October 1, 2013
// me@ryaneguerra.com
// Automatic calibration and characterization toolbench
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
// REG: I'm aliasing this namespace because Application is ambiguous between VSA DLL and Forms DLL.
using WinForms =  System.Windows.Forms;
using System.Linq;
using System.Text;

using IronPython.Hosting;
using Microsoft.Scripting.Hosting;

using Agilent.SA.Vsa;
using NumpyDotNet;

namespace MeasDemo
{
    /// <summary>
    /// SCG container for passing around SCG tuplets
    /// </summary>
    class SCGContainer
    {
        public Single smult_;
        public Single cmult_;
        public Single gmult_;
        public Double mag_;
        public Double phase_;
        public String smult_hex_;
        public String cmult_hex_;
        public String gmult_hex_;

        private double freq_khz_ = 0;

        /// <summary>
        /// Constructor for the SCG container class.
        /// </summary>
        /// <param name="smult"></param>
        /// <param name="cmult"></param>
        /// <param name="gmult"></param>
        public SCGContainer(Single smult, Single cmult, Single gmult, Double mag, Double phase)
        {
            smult_ = smult;
            cmult_ = cmult;
            gmult_ = gmult;
            mag_ = mag;
            phase_ = phase;
        }

        /// <summary>
        /// Overloaded ToString function changes output based on whether or not the HEX strings have been set.
        /// </summary>
        /// <returns>"0xAAAABBBB, 0xCCCCDDDD, 0xEEEEFFFF # MP=[0.1, -0.01]"</returns>
        public override String ToString()
        {
            if (smult_hex_ == null)
            {
                return String.Format("{0}f, {1}f, {2}f # MP=[{3}, {4}]", smult_, cmult_, gmult_, mag_, phase_);
            }
            else
            {
                return String.Format("0x{0}, 0x{1}, 0x{2} # MP=[{3}, {4}]", smult_hex_, cmult_hex_, gmult_hex_, mag_, phase_);
            }
        }

        /// <summary>
        /// Mutator for measurement frequency for this tuple.
        /// </summary>
        /// <param name="freq_khz">Set the measurement center frequency in kilohertz.</param>
        public void setMeasurementFreq_kHz(double freq_khz)
        {
            freq_khz_ = freq_khz;
        }

        /// <summary>
        /// Accessor for measurement frequency for this tuple.
        /// </summary>
        /// <returns>The measurement center frequency in kilohertz.</returns>
        public double getMeasurementFreq_kHz()
        {
            if (freq_khz_ == 0)
            {
                Console.WriteLine("ERROR: measurement frequency hasn't been measured yet!!!");
                return 0;
            }
            return freq_khz_;
        }
    }

    /// <summary>
    /// LOFT container for passing around IQ tuplets
    /// </summary>
    class LOFTContainer
    {
        public Int32 I_;
        public Int32 Q_;
        double freq_khz_ = 0;

        /// <summary>
        /// Constructor for the LOFT container class.
        /// </summary>
        /// <param name="I"></param>
        /// <param name="Q"></param>
        public LOFTContainer(int I, int Q)
        {
            if (I > 255 || I < 0 || Q > 255 || Q < 0)
            {
                Console.WriteLine("ERROR: Values OOB: I = {0}, Q = {1}", I, Q);
            }
            I_ = I;
            Q_ = Q;
        }

        /// <summary>
        /// Overloaded ToString function.
        /// </summary>
        /// <returns>"0x45, 0x29"</returns>
        public override String ToString()
        {
            return String.Format("0x{0:X2}, 0x{1:X2}", I_, Q_);
        }

        /// <summary>
        /// Mutator for measurement frequency for this tuple.
        /// </summary>
        /// <param name="freq_khz">Set the measurement center frequency in kilohertz.</param>
        public void setMeasurementFreq_kHz(double freq_khz)
        {
            freq_khz_ = freq_khz;
        }

        /// <summary>
        /// Accessor for measurement frequency for this tuple.
        /// </summary>
        /// <returns>The measurement center frequency in kilohertz.</returns>
        public double getMeasurementFreq_kHz()
        {
            if (freq_khz_ == 0)
            {
                Console.WriteLine("ERROR: measurement frequency hasn't been measured yet!!!");
                return 0;
            }
            return freq_khz_;
        }
    }

    /// <summary>
    /// This is a demonstration of a complete measurement.
    ///
    /// This program creates, sets up, starts a measurement, reads
    /// frequency and voltage data, dumps the data to the console,
    /// and exits the application.
    ///
    /// One would not normally combine all these steps into one routine.
    /// In particular, the creation of the 89600 application would normally be done
    /// only once at program start-up and kept around until this program
    /// is finished.
    /// </summary>
    class WSDAutoCal
    {
        // Global containers for configuration states. This isn't the best design.
        static SCGContainer current_SCG = null;
        static LOFTContainer current_TxLOFT = null;

        // Log File Global Pointer
        static System.IO.StreamWriter log_file = null;
        static String log_path = null;

        // Calibration File Global Pointer
        static System.IO.StreamWriter cal_file = null;
        static String cal_file_path = null;

        // Characterization File Global Pointer
        static System.IO.StreamWriter pwr_file = null;
        static String pwr_characterization_path = null;

        private static Dictionary<int, int> max_gain_dict = new Dictionary<int, int>()
        {
            {472, 25},
            {478, 25},
            {484, 25},
            {490, 25},
            {496, 25},
            //{502, 25}, // NOTE: this frequency has an anomoly from the VSA. I do not trust that thing at all
            {508, 25},
            {514, 25},
            {520, 25},
            {526, 25},
            {532, 25},
            {538, 25},
            {544, 26},
            {550, 28},
            {556, 29},
            {562, 30},
            {568, 31},
            {574, 31},
            {580, 33},
            {586, 33},
            {592, 35},
            {598, 35},
            {604, 35},
            {610, 35},
            {616, 34},
            {622, 34},
            {628, 34},
            {634, 34},
            {640, 34},
            {646, 34},
            {652, 32},
            {658, 31},
            {664, 31},
            {670, 31},
            {676, 31},
            {682, 31},
            {688, 31},
            {694, 31}
        };

        /// <summary>
        /// Tees the passed line to the console output AND the log file initialized at the beginning.
        /// </summary>
        /// <param name="str">The string to write</param>
        static void WriteLine(String str)
        {
            Console.WriteLine(str);
            if (log_file != null)
            {
                log_file = new System.IO.StreamWriter(log_path, true);
                log_file.WriteLine(str);
                log_file.Close();
            }
        }

        /// <summary>
        /// Print the passed string to the calibration file, if it exists.
        /// </summary>
        /// <param name="str">The string to write</param>
        static void WriteToCalFile(String str)
        {
            if (cal_file != null)
            {
                cal_file = new System.IO.StreamWriter(cal_file_path, true);
                cal_file.WriteLine(str);
                cal_file.Close();
            }
        }

        /// <summary>
        /// Print the passed string to the calibration file, if it exists.
        /// </summary>
        /// <param name="str">The string to write</param>
        static void WriteToCharacterizationFile(String str)
        {
            if (pwr_file != null)
            {
                pwr_file = new System.IO.StreamWriter(pwr_characterization_path, true);
                pwr_file.WriteLine(str);
                pwr_file.Close();
            }
        }

        // This attribute was randomly required by the GetFolderBrowser dialog. DUnno...
        [STAThread]
        static void Main(string[] args)
        {
            WriteLine("=====================================================");
            WriteLine("======== C# Factory Calibration version 0.9 ========");
            WriteLine("========= October 2013, me@ryaneguerra.com ==========");
            WriteLine("=====================================================");

            var input_attenuation_offset = 40;

            var user_dialog = new WinForms.FolderBrowserDialog();
            user_dialog.RootFolder = System.Environment.SpecialFolder.MyComputer;
            user_dialog.Description = "WURC Calibration: Select Log/Output File Directory - this is where the output files will be stored. If you cancel, the calibration will exit.";
            if (user_dialog.ShowDialog() != WinForms.DialogResult.OK)
            {
                // Set a default path if the user doesn't select something different.
                user_dialog.SelectedPath = "E:\\Dropbox\\Vuum_Wireless\\Engineering\\WURC_TxPower_Results";
                WriteLine(String.Format("--> User declined to specify output path; using default: {0}", user_dialog.SelectedPath));
            }

            // Open the log file for writing... note that everything is appended!
            log_path = user_dialog.SelectedPath + @"\autocal_log_file.txt";
            WriteLine(String.Format("--> Saving log in: {0}", log_path));
            log_file = new System.IO.StreamWriter(log_path, true); 
            log_file.WriteLine("");
            log_file.Close();

            // Instructions
            WriteLine("--> Acquiring Agilent 89600B Application...");
            WriteLine("    If this fails:");
            WriteLine("     1. quit all open application instances,");
            WriteLine("     2. connect the DUT to VSA input port on slot #4,");
            WriteLine("     3. power cycle the VSA,");
            WriteLine("     4. launch 'Vector Signal Analysis 14.0' application,");
            WriteLine("     5. select 'VSA Slot 4' from 'Hardware' menu,");
            WriteLine("     6. run hardware calibration,");
            WriteLine("     7. restart this application.");
            WriteLine("");

            // First, try getting a reference to an already running 89600 VSA
            Application app = ApplicationFactory.Create();
            bool isCreated = false;

            if (app == null)
            {
                WriteLine(" --> No running VSA host application detected, trying to init a new one.");
                WriteLine(" --> Please wait a minute...");
                // There is no running 89600 VSA, try to create a new one
                app = ApplicationFactory.Create(true, null, null, -1);
                isCreated = true;
            }
            // If we got here, then things should be good!
            WriteLine("--> VSA host acquired!");

            //Import WSDNode class; this API is a complete abomination. No wonder MSR killed this.
            //http://stackoverflow.com/questions/579272/instantiating-a-python-class-in-c-sharp
            //http://blogs.msdn.com/b/charlie/archive/2009/10/25/hosting-ironpython-in-a-c-4-0-program.aspx
            //http://stackoverflow.com/questions/1755572/ironpython-scriptruntime-equivalent-to-cpython-pythonpath/1756818#1756818
            WriteLine("--> Importing WSDNode class...");
            ScriptEngine engine = Python.CreateEngine();
            var paths = engine.GetSearchPaths();
            paths.Add("E:\\Programs\\IronPython\\Lib");
            paths.Add("E:\\Programs\\IronPython\\Lib\\site-packages");
           // paths.Add("C:\\Program Files\\IronPython 2.7\\Lib\\site-packages\\numpy");
            engine.SetSearchPaths(paths);
            ScriptSource source = engine.CreateScriptSourceFromFile("E:\\Dropbox\\Shared_Naren_Ryan_Sadia\\wsd_calibration_files\\wsdnode.py");
            ScriptScope scope = engine.CreateScope();
            source.Execute(scope);

            WriteLine("--> Instantiating WSDNode...");
            dynamic WSDNode = scope.GetVariable("WSDNode");
            // This states ACTUALLY instantiates an instance of the fucking class.
            dynamic node = null;
            try
            {
                node = WSDNode.Create();
            }
            catch (System.AccessViolationException)
            {
                WriteLine("--> ERROR: AccessViolationException. Is the selected serial device available? Couldn't access the device!");
                WriteLine("           Try closing all open python, puTTY, and/or screen sessions.");
                quitProgram(app, isCreated);
            }
            catch (System.UnauthorizedAccessException)
            {
                WriteLine("--> ERROR: UnauthorizedAccessException. Is the selected serial device available? Couldn't access the device!");
                WriteLine("           Try  closing all open python, puTTY, and/or screen sessions.");
                quitProgram(app, isCreated);
            }
            dynamic dev_type = node.CS_DevType();
            dynamic dev_id = node.CS_DevSerial();

            // Open the calibration file for writing, now that we know the serial number
            cal_file_path = user_dialog.SelectedPath + String.Format("\\wurc_cal_{0}.csv", dev_id);
            WriteLine(String.Format("--> Saving calibration file as: {0}", cal_file_path));
            cal_file = new System.IO.StreamWriter(cal_file_path);
            cal_file.WriteLine("");
            cal_file.Close();

            // Opena the characterization file for writing.
            pwr_characterization_path = user_dialog.SelectedPath + String.Format("\\wurc_characterization_{0}.csv", dev_id);
            WriteLine(String.Format("--> Saving characterization file as: {0}", pwr_characterization_path));
            pwr_file = new System.IO.StreamWriter(pwr_characterization_path);
            pwr_file.WriteLine("");
            pwr_file.Close();

            WriteLine("--> Setting defaults...");
            // Initialize node & set defaults
            initWSD(node);
            WriteLine("--> WSDNode ready!");

            WriteLine("--> Starting calibration...");

            app.IsVisible = true;				                    // Make VSA application window visible
            app.Title = "WSD Factory Calibration (Running)";		// Label the VSA main window

            // Get interfaces to major objects
            Measurement meas = app.Measurements.SelectedItem;
            Display disp = app.Display;

            // Set to defaults 
            app.Display.Preset();
            meas.Preset();
            meas.Reset();

            // Gather data, average, and update trace
            meas.Average.IsFast = true;
            meas.Average.IsRepeat = true;

            // Quick Sanity Check
            AcquireTrace(563e6, 12e6, app);

            // Pretty up the displays
            disp.Traces[0].YScaleAuto();
            disp.Traces[1].YScaleAuto();

            //========================================================
            // Run the calibration proceedure to calibrate the node.
            //========================================================
            if (false)
            {
                WriteLine(String.Format("--> Running autocalibration routine on: {0} {1}...", dev_type, dev_id));
                RunUHFCalibration(node, app);
            }

            //========================================================
            // Get the arbitrary frequency response of the attached WSD device.
            //========================================================
            if (false)
            {
                WriteLine(String.Format("--> Getting UHF Frequency Response of {0} {1}...", dev_type, dev_id));
                for (int txgain = 35; txgain <= 35; txgain = txgain + 5)
                {
                    // Set Tx gain to 30 dB
                    String gainstr = String.Format("n{0}", txgain);
                    WriteLine(String.Format("--> Running characterization for {0}", gainstr));
                    node.autocalExecute(String.Format("Q0{0}", gainstr));
                    pwr_characterization_path = user_dialog.SelectedPath + String.Format("\\wurc_characterization_{0}_{1}.csv", dev_id, gainstr);
                    pwr_file = new System.IO.StreamWriter(pwr_characterization_path);
                    pwr_file.Close();
                    RunUHFFrequencyResponse(input_attenuation_offset, node, app, false);
                }
            }

            //========================================================
            // Get the maximum frequency response of the attached WSD device for certificate characterization
            //========================================================
            if (true)
            {
                WriteLine(String.Format("--> Getting Maximum UHF Frequency Response of {0} {1}...", dev_type, dev_id));
                pwr_characterization_path = user_dialog.SelectedPath + String.Format("\\wurc_max_cw_tx_power_{0}.csv", dev_id);
                pwr_file = new System.IO.StreamWriter(pwr_characterization_path);
                pwr_file.Close();
                RunUHFFrequencyResponse(input_attenuation_offset, node, app, true);
            }

            // Last thing we do, we leave the VSA application displaying the last setup
            // continuously.
            meas.Average.IsRepeat = true;
            meas.IsContinuous = true;
            meas.Restart();

            // Pretty up the displays
            disp.Traces[0].YScaleAuto();
            disp.Traces[1].YScaleAuto();

            WriteLine(String.Format("--> Saving log in: {0}", log_path));
            WriteLine(String.Format("--> Saving calibration file as: {0}", cal_file_path));

            // Quit cleanly
            quitProgram(app, isCreated);
        }

        /// <summary>
        /// Run the whole calibration routine for the attached WSD in the UHF band. Depends on the subroutine RunCalibrationAt, and globals
        /// current_SCG and current_TxLOFT.
        /// 
        /// The set of calibration points is also defined in "wsd_settings.h"
        /// static const unsigned long CAL_LOFT_SIZE[]      = {26,          16};
        /// static const unsigned long CAL_LOWER_KHZ[]      = {473000,      2412000};
        /// static const unsigned long CAL_UPPER_KHZ[]      = {773000,      2487000};
        /// static const unsigned long CAL_STEP_KHZ[]       = {12000,       5000};
        /// </summary>
        /// <param name="node">Handle to the WSD Node instance. Used for controlling settings.</param>
        /// <param name="app">Handle to the VSA application. All other properties are derived from this.</param>
        static void RunUHFCalibration(dynamic node, Application app)
        {
            Display disp = app.Display;

            // Storage for calibration results
            List<SCGContainer> scg_results = new List<SCGContainer>(50);
            List<LOFTContainer> txloft_results = new List<LOFTContainer>(50);

            //// DEBUG Set TxIQMultiplier values
            //SCGContainer debug_scg = SetTxIQMagPhase(0.7, 7, node);
            //Console.WriteLine(String.Format("--> DEBUG: {0}", debug_scg.gmult_hex_));

            // Freeze updates to the Application (for speed)
            app.IsVisible = false;

            // DEBUG: Originally 473 - 773
            for (double centerf = 473e6; centerf <= 773e6; centerf += 12e6)
            {
                // Reset (or initialize) the global calibration value state variables.
                current_TxLOFT = new LOFTContainer(-1, -1);
                current_SCG = new SCGContainer(-100, -100, -100, 0.0, 0.0);

                // Pretty up the displays
                disp.Traces[0].YScaleAuto();
                disp.Traces[1].YScaleAuto();

                // Do calibration for a single frequency
                RunCalibrationAt(centerf, node, app);

                // Save SCG value (mind Hz/kHz units)
                current_SCG.setMeasurementFreq_kHz(centerf/1e3);
                scg_results.Add(current_SCG);

                // Save TxLOFT value (mind Hz/kHz units)
                current_TxLOFT.setMeasurementFreq_kHz(centerf/1e3);
                txloft_results.Add(current_TxLOFT);
            }

            // Print the results to the console
            WriteLine("================================================================================");
            WriteLine("============================= Calibration Table ================================");
            WriteLine("================================================================================");
            WriteLine("Center_Frequency, TxLOFT_I, TxLOFT_Q, SMult, CMult, GMult");
            for (int ii = 0; ii < scg_results.Count(); ii++)
            {
                SCGContainer scg = scg_results[ii];
                LOFTContainer txloft = txloft_results[ii];
                if (scg.getMeasurementFreq_kHz() != txloft.getMeasurementFreq_kHz())
                {
                    WriteLine(String.Format("ERROR: frequencies SCG: {0} != TxLOFT: {1} !", scg.getMeasurementFreq_kHz(), txloft.getMeasurementFreq_kHz()));
                }
                // Mind the MHz/kHz units, since the calibration file expects MHz.
                WriteLine(String.Format("{0}, {1}, {2}", scg.getMeasurementFreq_kHz()/1e3, txloft.ToString(), scg.ToString()));
            }
            WriteLine("================================================================================");
            WriteLine("================================================================================");

            // Restore updates to the Application so we see what's up
            app.IsVisible = true;

            // Print the header of the new calibration file
            PrintCalHeader(node);
            WriteToCalFile("##################################################################################");
            WriteToCalFile("@@BAND 00");
            WriteToCalFile("##################################################################################");
            WriteToCalFile("@@TX_LOFT ############################################");
            WriteToCalFile("# Gain, TX_I, TX_Q");
            // Print the
            for (int gain = 0; gain < System.Math.Min(26, txloft_results.Count()); gain++)
            {
                LOFTContainer txloft = txloft_results[gain];
                WriteToCalFile( String.Format("{0,2}, {1} # NOTE: for freq {2}, not gain", gain, txloft.ToString(), txloft.getMeasurementFreq_kHz()/1e3) );
            }
            WriteToCalFile("");
            WriteToCalFile("@@IQ_IMBALANCE #######################################");
            WriteToCalFile("# FREQ_MHz, SIN, COS, GAIN");
            for (int ii = 0; ii < scg_results.Count(); ii++)
            {
                SCGContainer scg = scg_results[ii];
                WriteToCalFile( String.Format("{0}, {1}", scg.getMeasurementFreq_kHz()/1e3, scg.ToString()) );
            }
            WriteToCalFile("");
            WriteToCalFile("@@RX_LOFT ############################################");
            WriteToCalFile("# RX_I, RX_Q");
            WriteToCalFile("0x00, 0x01 # NOTE: this is just made up for now.");
            WriteToCalFile("");

            //WriteToCalFile("##################################################################################");
            //WriteToCalFile("@@BAND 01);
            //WriteToCalFile("##################################################################################");
            //WriteToCalFile("@@TX_LOFT ############################################");
            //WriteToCalFile("# Gain, TX_I, TX_Q");
        }

        /// <summary>
        /// Print the header of the new calibration file. Based on some node parameters
        /// </summary>
        /// <param name="node">Handle to the WSDNode object.</param>
        static void PrintCalHeader(dynamic node)
        {
            WriteToCalFile("##################################################################################");
            WriteToCalFile("## Machine-generated calibration file for WSD Daughtercard");
            WriteToCalFile("##   (I'm a lumberjack and I'm okay)");
            WriteToCalFile("##");
            WriteToCalFile( String.Format("## Date: {0} {1}", DateTime.Now.ToShortDateString(), DateTime.Now.ToShortTimeString()) );
            WriteToCalFile( String.Format("## Serial: 0x{0}", node.dev_serial) );
            WriteToCalFile("## Version: 1");
            WriteToCalFile("## Created By:  C# VSA API v1");
            WriteToCalFile("##################################################################################");
            WriteToCalFile("");
        }

        /// <summary>
        /// Subroutine to to run automatic calibration of an attached WSD device at a single center frequency.
        /// </summary>
        /// <param name="freq_hz">The frequency at which to perform calibration. Specified in Hz.</param>
        /// <param name="node">Handle to the WSD Node instance. Used for controlling settings.</param>
        /// <param name="app">Handle to the VSA application. All other properties are derived from this.</param>
        static void RunCalibrationAt(double freq_hz, dynamic node, Application app)
        {
            WriteLine(String.Format("--> Starting calibration at: {0} kHz...", freq_hz / 1000));
            //Makes VSA application handles easy to access
            Measurement meas = app.Measurements.SelectedItem;
            Display disp = app.Display;

            double loftFreq = freq_hz;
            double ssbFreq = freq_hz - 1e6;     // The error signal to measure for SSB calibration, NOT desired signal.
            double acquisition_span = 5e6;

            // Set the transmit center frequency--
            // the command takes arg in kHz, C# app uses Hz
            String cmd_str = String.Format("Q0D{0}", (int)freq_hz / 1000);
            WriteLine(String.Format("--> Sending {0} ...", cmd_str));
            node.autocalExecute( cmd_str );

            // Set TxLOFT values
            SetTxLOFT(128, 128, node);

            // BEGIN NAREN's LOFT CAL CODE
            // ==================================================================
            // Tx LOFT Calibration
            // ==================================================================

            // Reset the TxLOFT state (used to prevent extraneous reads/writes)
            current_TxLOFT = new LOFTContainer(-1, -1);

            // Zero DAC output & autorange the result
            node.autocalExecute("sm4");
            meas.Input.Analog.Channels[0].AutoRange();
            meas.Input.Analog.Channels[0].AutoRange();
            meas.Input.Analog.Channels[0].AutoRange();
            meas.Input.Analog.Channels[0].AutoRange();

            // Storing Minimum Error for Comparison
            double minErr;
            double curErr;
            // Stored loft calibration values
            int tx_i_loft = 0;
            int tx_q_loft = 0;
            // Loop counter
            int i, j = 0;

            // Variables for "correct" TX LOFT calibration method
            int gx, gy, curI, curQ = 0;
            int bestQuad = -1;

            // Second iteration search
            int hi_I, lo_I, hi_Q, lo_Q;
            
            // ACTUAL Calibration procedure as dictated by Diagram 4.7
            //		in LMS programming and calibration guide

            // Min Err reset
            minErr = 99999.0;
            // 1. Figure out the quadrant, apply +/-1 mV offset to each quadrant.
            //		Each LSB is 0.125 mv and 10000000 is zero.
            // 	Thus, +1mv = 0b1000,1000=0x88 and -1mV = 0b0111,1000=0x78
            // -- Create Quadrant Array (four quadrants by 2 (i/q) values)

            int[,] quadArr = new int[4, 2]  {
                                    {0x88,0x88},    // -- Quadrant 1 (1+1j)
                                    {0x88,0x78},    // -- Quadrant 2 (1-1j)
                                    {0x78,0x78},    // -- Quadrant 3 (-1-1j)
                                    {0x78,0x88}     // -- Quadrant 4 (-1+1j)
			        	           };

            // -- Loop through four quadrants, find best (to minimize search space)
            for (i = 0; i < 4; i++)
            {
                SetTxLOFT(quadArr[i, 0], quadArr[i, 1], node);
                // Get measurement
                AcquireTrace(freq_hz, acquisition_span, app);
                // Calculate power in specified band
                curErr = GetPower(loftFreq, 0.1e6, app);

                //curErr = wsd_measLOFTval(,;
                if (curErr < minErr)
                {
                    bestQuad = i + 1;
                    minErr = curErr;
                }
            }
            // -- Set gx, gy based on quadrant
            if (bestQuad == 1) { gx = 1; gy = 1; }
            else if (bestQuad == 2) { gx = 1; gy = -1; }
            else if (bestQuad == 3) { gx = -1; gy = -1; }
            else if (bestQuad == 4) { gx = -1; gy = 1; }
            else
            { // Should NEVER happen
                gx = 0; gy = 0;
                WriteLine("ERROR: TxLOFT Cal Quadrant error!");
            }

            // Min Err reset
            minErr = 99999.0f;
            for (i = 0; i < 128; i += 8)
            {  	// TX_I
                curI = 128 + i * gx;
                for (j = 0; j < 128; j += 8)
                {	// TX_Q
                    curQ = 128 + j * gy;
                    SetTxLOFT(curI, curQ, node);
                    // Get measurement
                    AcquireTrace(freq_hz, acquisition_span, app);
                    // Calculate power in specified band
                    curErr = GetPower(loftFreq, 0.1e6, app);
                    if (curErr < minErr)
                    {
                        tx_i_loft = curI;
                        tx_q_loft = curQ;
                        minErr = curErr;
                    }
                }
            }

            // Min Err reset
            minErr = 99999.0f;

            hi_I = tx_i_loft + 4 + 1;
            lo_I = tx_i_loft - 4;
            hi_Q = tx_q_loft + 4 + 1;
            lo_Q = tx_q_loft - 4;

            for (i = lo_I; i < hi_I; i += 1)
            {  	// TX_I
                curI = i;
                for (j = lo_Q; j < hi_Q; j += 1)
                {	// TX_Q
                    curQ = j;
                    SetTxLOFT(curI, curQ, node);
                    // Get measurement
                    AcquireTrace(freq_hz, acquisition_span, app);
                    // Calculate power in specified band
                    curErr = GetPower(loftFreq, 0.1e6, app);
                    if (curErr < minErr)
                    {
                        tx_i_loft = curI;
                        tx_q_loft = curQ;
                        minErr = curErr;
                    }
                }
            }


            //DEBUG - remove these lines
//            tx_i_loft = 0x80;
//            tx_q_loft = 0x80;


            // Set optimal TxLOFT values before starting next loop.
            SetTxLOFT(tx_i_loft, tx_q_loft, node);

            // Print result
            WriteLine(String.Format("--> Optimal TxLOFT: I = 0x{0}, Q = 0x{1}", tx_i_loft.ToString("X2"), tx_q_loft.ToString("X2")));
 
            // Normal DDS Output - with TxLOFT calibrated, re-enable 1 MHz sine wave & autorange
            node.autocalExecute("sm1");
            meas.Input.Analog.Channels[0].AutoRange();
            meas.Input.Analog.Channels[0].AutoRange();
            meas.Input.Analog.Channels[0].AutoRange();
            meas.Input.Analog.Channels[0].AutoRange();
            
            // ==================================================================
            // Tx SSB Calibration
            // ==================================================================

            // Reset the TxLOFT state (used to prevent extraneous reads/writes)
            // NOTE: this currently doesn't do anything since SCG writes are currently atomic (can't partially write)
            current_SCG = new SCGContainer(-100, -100, -100, 0.0, 0.0);
            
            // Get measurement
            AcquireTrace(freq_hz, acquisition_span, app);
            // Calculate power in specified band
//            double pwr = GetPower(562e6, 0.1e6, app);

            // Cycling Variables
            double low_dB = -0.7;
            double coarse_magStep = 0.1; // 
            double fine_magStep = 0.01; // 

            double low_phase = -7.0;
            double coarse_phaseStep = 1.0;
            double fine_phaseStep = 0.1;

//            double coarse_mag = 0.0;
//            double coarse_phase = 0.0;
            double bestMag = 0.0;
            double bestPhase = 0.0;
            double curMag = 0.0;
            double curPhase = 0.0;

	        // Counter for floating point loop indexing
//            double fp_cnt = 0.0;
            double fp_cntMAG = 0.0;
            double fp_cntPHASE = 0.0;

	        // *** FOUR LOOPS ***
	        // -- COARSE GAIN --
//	        coarse_mag = 0.7;	// SETTING
//	        coarse_phase = 0.0;	// --- INITIAL VALUES

	        minErr = 99999.0;
	        fp_cntPHASE = 14.0;
	        for(i=0; i<15; i++) {

		        curPhase = low_phase + (fp_cntPHASE *  coarse_phaseStep);
		        fp_cntMAG = 14.0;

		        for(j=0; j<15; j++) {

			        curMag = low_dB + (fp_cntMAG *  coarse_magStep);

                    SetTxIQMagPhase(curMag, curPhase, node);
                    // Get measurement
                    AcquireTrace(freq_hz, acquisition_span, app);
                    // Calculate power in specified band - this is the ERROR IQ imbalance signal,
                    // NOT the desired signal.
                    curErr = GetPower(ssbFreq, 0.1e6, app);
			        if(curErr<minErr) {
			        //if(curErr<minErr) {
				        bestMag = curMag;
				        bestPhase = curPhase;
				        minErr = curErr;
			        }

			        fp_cntMAG = fp_cntMAG - 1.0;
			        //xil_printf("%8x,%8x,%8x\r\n", util_float2int(curMag), util_float2int(curPhase), util_float2int(curErr));
		        }

		        fp_cntPHASE = fp_cntPHASE - 1.0;
	        }

	        // Fine Loop -- Update low mag/phase
	        low_phase = bestPhase - 1.0;
	        low_dB = bestMag - 0.1;

            WriteLine(String.Format("--> Best Coarse IQ: Mag = {0}, Phase = {1}", bestMag, bestPhase));

	        minErr = 99999.0;
	        fp_cntPHASE = 20.0;
	        for(i=0; i<21; i++) {

		        curPhase = low_phase + (fp_cntPHASE *  fine_phaseStep);
		        fp_cntMAG = 20.0;


		        for(j=0; j<21; j++) {

			        curMag = low_dB + (fp_cntMAG *  fine_magStep);

                    SetTxIQMagPhase(curMag, curPhase, node);
                    // Get measurement
                    AcquireTrace(freq_hz, acquisition_span, app);
                    // Calculate power in specified band
                    curErr = GetPower(ssbFreq, 0.1e6, app);
			        //if(isless(curErr,minErr)) {
			        if(curErr<minErr) {
				        bestMag = curMag;
				        bestPhase = curPhase;
				        minErr = curErr;
			        }

			        fp_cntMAG = fp_cntMAG - 1.0;
			        //xil_printf("%8x,%8x,%8x\r\n", util_float2int(curMag), util_float2int(curPhase), util_float2int(curErr));
		        }

		        fp_cntPHASE = fp_cntPHASE - 1.0;
	        }

            // Save the result TxSCG setting.
            current_SCG = SetTxIQMagPhase(bestMag, bestPhase, node);

            // Print result
            WriteLine(String.Format("--> Optimal Fine IQ: Mag = {0}, Phase = {1}", bestMag, bestPhase));
            
            // ==================================================================
            // END Calibration
            // ==================================================================
        }

        /// <summary>
        /// Quit the running application, used after errors or once everything is
        /// finished running.
        /// </summary>
        /// <param name="app">Handle to the VSA application. All other properties are derived from this.</param>
        /// <param name="isCreated">Boolean created during application initialization to keep track of 
        /// whether or not the application was created by this script or was already open when it ran.</param>
        static void quitProgram(Application app, Boolean isCreated)
        {
            WriteLine("--> Press enter to exit program...");
            Console.ReadLine();

            app.Title = "";		// Revert to the old title

            if (isCreated)
                app.Quit();		// Exit 89600 VSA if I started it

            Environment.Exit(0);
        }

        /// <summary>
        /// Activates and moves the Display's band power marker to the passed
        /// frequency location and measures the power at that location.
        /// NOTE: You MUST run AcquireTrace(...) before calling this to update the trace
        ///       this function does NOT update the trace for you!
        /// </summary>
        /// <param name="freq_center">The center frequency of the measurement to be made.</param>
        /// <param name="meas_span">The span of the measurement to be made. The left and right boundaries of
        /// the measurement MUST be within the left and right boundaries of the trace for an accurate measurement.</param>
        /// <param name="app">Handle to the VSA application. All other properties are derived from this.</param>
        /// <returns>Returns the measured power within the specified marker domain</returns>
        static double GetPower(double freq_center, double meas_span, Application app)
        {
            // Make a local handle for the trace marker
            Marker pwrmarkr = app.Display.Traces[0].Markers[0];
            pwrmarkr.IsBandVisible = true;
            pwrmarkr.BandCalc = MarkerBandCalc.Mean;
            pwrmarkr.BandType = MarkerBandType.Power;
            pwrmarkr.BandSpan = meas_span;  // 0.5 MHz measurement span
            pwrmarkr.XData = freq_center;

            return pwrmarkr.BandPowerResult; ;
        }

        /// <summary>
        /// Runs a single trace measurement and stops. This is a single, rather than
        /// continuous measurement. The trace is stored in the VSA application memory,
        /// and if the application isn't hidden, it is updated on-screen.
        /// </summary>
        /// <param name="centerf">The center frequency of the trace aquisition in Hz</param>
        /// <param name="span">The span of the trace acquisition; this should be just large enough to work,
        /// and no larger than 24 MHz.</param>
        /// <param name="app">Handle to the VSA application. All other properties are derived from this.</param>
        static void AcquireTrace(double centerf, double span, Application app)
        {
            Measurement meas = app.Measurements.SelectedItem;
            Display disp = app.Display;

            // TODO: play with this average count to try and speed up the measurement.
            int average_count = 5;

            // Set center and span frequencies
            meas.Frequency.Center = centerf;
            meas.Frequency.Span = span;
            // 25601 Number of non-aliased points to display.
            // 12801 is a decent number that seems to balance speed and precision.
            // TODO: Let's test and see if we can reduce this even more.
            meas.Frequency.Points = 12801;

            // Set input range
            //meas.Input.Analog.Channels[0].Range = 1.0;		// 1 Volt peak
            // Note: this may have to be run several times when the power of the signal
            // changes radically. The outer calling loop should handle that since this
            // does take a little time.
            //meas.Input.Analog.Channels[0].AutoRange();

            // The default trace A shows a spectrum. A = 0, it seems
            // Set trace 0 to display volts so the upcoming read will return volts.
            disp.Traces[0].Format = TraceFormatType.LogMagnitude;
            disp.Traces[0].YScaleAuto();

            // Set for single measurement rather than repeated for speed.
            meas.IsContinuous = false;
            meas.Average.IsRepeat = false;
            meas.Average.Style = AverageStyle.Rms;
            meas.Average.Count = average_count;

            // Start measurement
            meas.Restart();

            /*
             * // REG: this code block was in the example and I'd like
             * // to save it for later use.
            // Wait for MeasurementDone, but don't bother it too often
            double timeout = 5;			// 5 second timeout
            bool isMeasDone = false;

            while (!isMeasDone && timeout >= 0.0)
            {
                System.Threading.Thread.Sleep(100);
                timeout -= 0.1;
                isMeasDone = (meas.Status.Value & StatusBits.MeasurementDone) != 0;
            }
             
            // Check to see if measurement was stuck
            if (!isMeasDone)
                WriteLine("Measurement failed to complete");
            */

            // Wait for our single measurement to be done.
            // Note: if in continuous acquisition mode, this will never return.
            // In that case, use the above commented code.
            meas.WaitForMeasurementDone();

            return;
        }

        /// <summary>
        /// Routine that measures and print the UHF frequency response of an attached WSD Node.
        /// MAke sure that the instantiated node is a WARP node, not a WSD node.
        /// </summary>
        /// <param name="dev">Handle to the WSD Node instance. Used for controlling settings.</param>
        /// <param name="app">Handle to the VSA application. All other properties are derived from this.</param>
        static void RunUHFFrequencyResponse(int input_attenuation_offset, dynamic dev, Application app, Boolean use_max_gain)
        {
            Measurement meas = app.Measurements.SelectedItem;
            Display disp = app.Display;
            double pwr;
            List<Double> freqs = new List<Double>(64);
            List<Double> results = new List<Double>(64);
            List<Double> gains = new List<Double>(64);

            if (use_max_gain)
            {
                foreach (KeyValuePair<int,int> thedict in WSDAutoCal.max_gain_dict)
                {
                    // Set the transmit gain of the WURC node
                    string cmd_str = String.Format("Q0n{0}", thedict.Value);
                    WriteLine(String.Format("--> Sending: {0}", cmd_str));
                    dev.autocalExecute(cmd_str);
                    // Set the center frequency of the WURC node
                    cmd_str = String.Format("Q0D{0}", thedict.Key*1000);
                    WriteLine(String.Format("--> Sending: {0}", cmd_str));
                    dev.autocalExecute(cmd_str);

                    // After setting frequency, measure the desired power across
                    // an 11-MHz channel bandwidth
                    AcquireTrace(thedict.Key*1e6, 11e6, app);
                    pwr = GetPower(thedict.Key*1e6, 10e6, app);

                    // Save the results, but also print to screen
                    results.Add(pwr);
                    freqs.Add(thedict.Key*1e6);
                    gains.Add(thedict.Value);
                    WriteLine(String.Format("--> Signal Power: {0} dBm", pwr));
                }
            }
            else
            {
                for (double centerf = 473e6; centerf <= 773e6; centerf += 3e6)
                {
                    // Format and send the frequency-setting command string to the WARP node
                    string cmd_str = String.Format("Q0D{0}", centerf / 1000);
                    WriteLine(String.Format("--> Sending: {0}", cmd_str));
                    dev.autocalExecute(cmd_str);

                    //WriteLine("--> Measuring Pwr @ {0} ({1})...");
                    // After setting frequency, measure the desired power across
                    // an 11-MHz channel bandwidth
                    AcquireTrace(centerf, 11e6, app);
                    pwr = GetPower(centerf, 10e6, app);
                    // Save the results, but also print to screen
                    results.Add(pwr);
                    freqs.Add(centerf);
                    WriteLine(String.Format("--> Signal Power: {0} dBm", pwr));
                }
            }

            WriteLine("--> {0} Measurements Made. Printing Results:");
            WriteLine("--> {0} Measurements Made. Printing Results:");
            WriteLine("Frequency, Channel_Power");
            WriteToCharacterizationFile("Frequency (MHz), CW Power (dBm), Tx Gain (dB)");

            // Write measured channel power as a function of frequency; taking into account input attenuation.
            for (int ii = 0; ii < results.Count; ii++)
            {
                String temp = String.Format("{0}, {1}, {2}", freqs[ii]/1e6, results[ii] + input_attenuation_offset, gains[ii]);
                WriteLine(temp);
                WriteToCharacterizationFile(temp);
            }
        }

        /// <summary>
        /// Write the passed Tx I/Q DCO values to the attached node 
        /// </summary>
        /// <param name="Tx_I">The new I LOFT DCO calibration value to write to 0x42: integer</param>
        /// <param name="Tx_Q">The new Q LOFT DCO calibration value to write to 0x43: integer</param>
        /// <param name="node">Handle to the WSD Node instance. Used for controlling settings.</param>
        /// <returns>The passed IQ LOFTR tuplet in a container class.</returns>
        static void SetTxLOFT(int Tx_I, int Tx_Q, dynamic node)
        {
            if (Tx_I < 0 || Tx_Q > 255 || Tx_Q < 0 || Tx_Q > 255)
            {
                WriteLine(String.Format("ERROR: TxI: {0} or TxQ: {1} is OOB!", Tx_I, Tx_Q));
                return;
            }

            // Save writes by only updating I if it's different from the current settings.
            if (current_TxLOFT.I_ != Tx_I)
            {
                // If the currently-set I value doesn't match the new one; update.
                string sTx_I = Tx_I.ToString("X2");
                node.autocalExecute(String.Format("Q0w42{0}", sTx_I));
                current_TxLOFT.I_ = Tx_I;
            }

            // Save writes by only updating Q if it's different from the current settings.
            if (current_TxLOFT.Q_ != Tx_Q)
            {
                // If the currently-set Q value doesn't match the new one; update.
                string sTx_Q = Tx_Q.ToString("X2");
                node.autocalExecute(String.Format("Q0w43{0}", sTx_Q));
                current_TxLOFT.Q_ = Tx_Q;
            }

            return;
        }

        /// <summary>
        /// Calculates and sets the Tx IQ compensation values specified by the given magnitude and phase.
        /// These are written to the passed WSD node, and returned in an SCG container tuplet for post-
        /// processing.
        /// </summary>
        /// <param name="mag_db">The new IQ magnitude correction factor in dB. Double</param>
        /// <param name="phase_deg">The new IQ phase correction factor in degrees. Double</param>
        /// <param name="node">Handle to the WSD Node instance. Used for controlling settings.</param>
        /// <returns>The calculated SCG tuplet in a container class.</returns>
        static SCGContainer SetTxIQMagPhase(double mag_db, double phase_deg, dynamic node)
        {
            // Check the bounds of the passed values.
            /*if (mag_db < -0.7 || mag_db > 0.7 || phase_deg < -7 || phase_deg > 7)
            {
                WriteLine("ERROR: mag_db: {0} or phase_deg: {1} is OOB!", mag_db, phase_deg);
                return null;
            }*/

            Single f32_mag_db = (Single)(mag_db / 10.0);
            Single f32_phase_deg = (Single)phase_deg;

            Single f32_ten = 10.0F;
            Single f32_one = 1.0F;

            // Backoff to prevent Fixed 12_11 overflow
            Single f32_ADJ_GAIN = 4.8828125e-4F;

            // Convert to linear magnitude and radians
            Single f32_phase_rad = f32_phase_deg * 1.7453292e-02F;
            Single f32_mag_lin = (Single)Math.Pow(f32_ten, f32_mag_db);


            // Compute Sin/Cos multipliers
            Single f32_smult = f32_mag_lin * (Single)Math.Sin(f32_phase_rad);
            Single f32_cmult = f32_mag_lin * (Single)Math.Cos(f32_phase_rad);

            // Computer relative gain
            Single f32_gmult = (Single)1.0 / Math.Max(f32_one + f32_smult, f32_cmult) - f32_ADJ_GAIN;

            // Have Python caluculate the HEX representation of these numbers
            // and commite them to the board.
            dynamic py_scg = node.setSCGDirect(f32_smult, f32_cmult, f32_gmult);


            // Return the caluculated tuplet for processing and storage.
            SCGContainer scg = new SCGContainer(f32_smult, f32_cmult, f32_gmult, mag_db, phase_deg);
            scg.smult_hex_ = py_scg.sinmult_hex;
            scg.cmult_hex_ = py_scg.cosmult_hex;
            scg.gmult_hex_ = py_scg.gain_hex;
            return scg;
        }

        /// <summary>
        /// Initialize the passed WSD Node to calibration default settings.
        /// </summary>
        /// <param name="node">Handle to to WSD Node. Used for control.</param>
        static void initWSD(dynamic node)
        {
            //TODO - update firmware and enable unambiguous autocal
            // Disable calibration loading, AGC, Tx/Rx switching
            node.autocalExecute("Q0u0");
            node.autocalExecute("dia");
            node.autocalExecute("Q0x0");
            // Initialization function for WSD
            node.autocalExecute("Q0A");
            node.autocalExecute("Q0x0");
            // Ensure 1 MHz DDS sine wave is radio output
            node.autocalExecute("sm1");
            node.autocalExecute("Q0V4");
            // Set Tx gain to 25 dB
            node.autocalExecute("Q0n25");
            // Set to Transmit Mode
            node.autocalExecute("Q0N");
            //TODO - other default settings, if any.
        }
    }
}
