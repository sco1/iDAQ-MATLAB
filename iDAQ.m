classdef iDAQ < handle & AirdropData
    % IDAQ Provides a set of data processing and data visualization tools
    % for Wamore's iDAQ
    % 
    % iDAQobj = iDAQ() prompts the user to select an iDAQ data file to 
    % process and returns an instance of the iDAQ class, iDAQobj.
    %
    % iDAQobj = iDAQ(filepath) processes the iDAQ data file specified by 
    % filepath and returns an instance of the iDAQ class, iDAQobj.
    % 
    % iDAQ supports the following file types:
    %     LOG.*       Raw iDAQ log file output
    %     *.iDAQ      Renamed raw iDAQ log file output
    %     *.csv       CSV file in the format output by Wamore's log decoder
    %     *_proc.mat  Saved instance of an iDAQ class instance
    %
    % iDAQ Methods:
    %     addID           - Associate a unique ID with the loaded data set
    %     finddescentrate - Interactively identify descent rate
    %     fixedwindowtrim - Interactively trim all loaded iDAQ data using a fixed time window
    %     save            - Save the current iDAQ data to a MAT file
    %     trimdata        - Trim all loaded data using user-specified indices
    %     windowtrim      - Interactively window and trim all loaded iDAQ data
    %
    % iDAQ Static Methods:
    %     batch           - Batch process a list or directory of raw iDAQ log files
    %     calcpress_alt   - Map barometric pressure to Standard Atmosphere pressure altitude
    %     fixedwindowdata - Interactively obtain data indices of a fixed-width plot window
    %     wamoredecoder   - Pass the input filepath to Wamore's log decoder via a native system call
    %     windowdata      - Interactively obtain data indices of a user-specified plot window
    
    properties
        datafilepath      % Absolute file path to analyzed data file
        analysisdate      % Date of analysis, ISO 8601, yyyy-mm-ddTHH:MM:SS+/-HH:MMZ
        dropID            % User Specified numeric drop ID
        time              % Time, milliseconds, since DAQ was powered on
        gyro_x            % X gyro output, deg/sec, with 0.05 deg/sec resolution
        gyro_y            % Y gyro output, deg/sec, with 0.05 deg/sec resolution
        gyro_z            % Z gyro output, deg/sec, with 0.05 deg/sec resolution
        accel_x           % X accelerometer output, Gs, with 0.00333 G resolution
        accel_y           % Y accelerometer output, Gs, with 0.00333 G resolution
        accel_z           % Z accelerometer output, Gs, with 0.00333 G resolution

        link_1            % Raw strain link ADC data, must be converted to force
        link_2            % Raw strain link ADC data, must be converted to force
        link_3            % Raw strain link ADC data, must be converted to force
        link_4            % Raw strain link ADC data, must be converted to force
        link_5            % Raw strain link ADC data, must be converted to force
        adc_1             % Internal DAQ value, engineering use only
        adc_2             % On-board 5V supply monitor
        adc_3             % Internal DAQ value, engineering use only
        adc_4             % Internal DAQ value, engineering use only
        adc_5             % Approximate battery voltage
        adc_6             % On-board 3.3V supply monitor
        adc_7             % User input analog voltage #1, 0V to 4.0V
        adc_8             % User input analog voltage #2, 0V to 4.0V
        adc_temp          % Internal DAQ value, engineering use only
        din_1             % Digital input #1 - Lanyard switch status
        din_2             % General purpose digital input: 0-Low 1-High
        din_3             % General purpose digital input: 0-Low 1-High
        din_4             % General purpose digital input: 0-Low 1-High
        pwrsw             % Power switch status: 0-Pressed 1- Open

        pstemp            % Temperature reported by the pressure sensor, Celsius
        pressure          % Temperature reported by the pressure sensor, Pascals
        GPS_Msgs          % Number of NMEA GPS mesages received from the GPS module
        GPS_Valid         % GPS valid signal: V-Navigation warning A-Valid Data
        GPS_Mode          % GPS mode: M-Manual A-Automatic
        GPS_FixMode       % GPS fix mode; 1-Fix not available 2-2D fix 3-3D fix
        GPS_DateTime      % GPS date and time, YYYYMMDD-HHMMSS
        GPS_SatsInView    % Number of satellites in view
        GPS_SatsInUse     % Number of satellites in use
        GPS_Latitude      % GPS Latitude, decimal degrees
        GPS_Longitude     % GPS Longitude, decimal degrees
        GPS_Altitude      % GPS Altitude, meters
        GPS_GroundSpeed   % GPS Groundspeed, knots true
        press_alt_meters  % Pressure altitude, meters
        press_alt_feet    % Pressure altitude, meters
        descentrate_fps   % Calculated descent rate, feet per second
        descentrate_mps   % Calculated descent rate, meters per second
    end
    
    properties (Access = private)
        nlines
        nheaderlines = 1;
        ndatapoints
        chunksize = 5000;
        formatspec = '%10u %13.6f %13.6f %13.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %6u %6f %6f %6f %6f %1u %8f %f %8u %c %c %1u %s %3u %3u %f %f %f %f';
        propstoignore = {'datafilepath', 'analysisdate', 'dropID', 'descentrate_fps', 'descentrate_mps'};  % Properties to ignore during data trimming
        defaultwindowlength = 12;  % Default data windowing length, seconds
    end
    
    methods
        function dataObj = iDAQ(filepath)
            % iDAQ Class Constructor
            %
            % iDAQobj = iDAQ() prompts the user to select an iDAQ data file to 
            % process and returns an instance of the iDAQ class, iDAQobj.
            %
            % iDAQobj = iDAQ(filepath) processes the iDAQ data file specified by 
            % filepath and returns an instance of the iDAQ class, iDAQobj.
            %
            % The file extension of filepath is parsed and used to select
            % the appropriate processing pipeline. The constructor returns
            % an instance of the iDAQ class.
            %
            % Processing pipeline:
            %     LOG.*  - Call Wamore logdecoder.exe, parse resulting *.CSV into iDAQ class properties
            %     *.iDAQ - Call Wamore logdecoder.exe, parse resulting *.CSV into iDAQ class properties
            %     *.csv  - Parse into iDAQ class properties
            %     *.mat  - Load iDAQ class instance directly
            
            % Choose correct behavior based on # of arguments passed
            if nargin == 1
                filepath = fullfile(filepath);  % Ensure correct file separators
            else
                % Prompt user to select a file if no input is passed
                [file, pathname] = uigetfile({'LOG.*;*.iDAQ', 'Raw iDAQ Log File (LOG.*, *.iDAQ)'; ...
                                              '*.csv', 'Decoded Raw Log File (*.csv)'; ...
                                              '*_proc.mat', 'Processed Log File (*_proc.mat)'; ...
                                              '*.*', 'All Files'}, ...
                                             'Select Wamore iDAQ data file' ...
                                             );
                filepath = [pathname file];
            end
            
            % Choose correct processing behavior based on file extension
            [~, ~, ext] = fileparts(filepath);
            switch lower(ext)
                case '.csv'
                    % Assume CSV file with the same format as the raw
                    % decoder CSV output
                    % Parse decoded CSV & process
                    dataObj.datafilepath = filepath;
                    processCSV(dataObj);
                case '.mat'
                    % See if we have a saved instance of the TSPI class
                    % Index of first class instance returned with boolean
                    [chkbool, idx] = AirdropData.matclassinstancechk(filepath, 'iDAQ');
                    if chkbool
                        matfileinfo = whos('-file', filepath);
                        tmp = load(filepath, matfileinfo(idx).name);
                        dataObj = tmp.(matfileinfo(idx).name);  % Pull the object out of the structure
                    else
                        err.identifier = 'iDAQ:iDAQ:unsupportedMATfile';
                        err.message = sprintf('MAT file, ''%s'', does not contain any supported data types\n', filepath);
                        err.stack = dbstack('-completenames');
                        error(err);
                    end
                case '.idaq'
                    % Assume *.iDAQ file is the renamed raw binary output
                    % from the iDAQ. Same processing path as LOG.*** files.
                    
                    % Decode raw data and process the resulting CSV
                    dataObj.datafilepath = iDAQ.wamoredecoder(filepath);
                    processCSV(dataObj);
                otherwise
                    % Need to figure out how to best catch LOG.*** files,
                    % catch them here for now. This will also catch invalid
                    % files, which we can rely on error checking to toss
                    % out as we go through our methods.
                    
                    % Decode raw LOG.*** file and process the resulting CSV
                    dataObj.datafilepath = iDAQ.wamoredecoder(filepath);
                    processCSV(dataObj);
            end
        end
        
        
        function windowtrim(dataObj)
            % WINDOWTRIM spawns a new figure window and axes object and
            % plots the iDAQ's pressure altitude (feet) vs. time (seconds)
            %
            % Two draggable lines are generated in the axes object, which
            % the user can drag to specify an arbitrary time window. UIWAIT
            % and MSGBOX is used to block MATLAB execution until the user
            % closes the MSGBOX dialog. When execution resumes, the data
            % indices are used to trim all of the appropriate internal data
            
            % Spawn new figure window and plot pressure altitude (feet) vs.
            % time (seconds). Because time is stored internally as integer
            % milliseconds from power on, need to convert to a double to
            % avoid integer division and then divide by 1000 to get seconds
            fig = figure;
            ax = axes('Parent', fig);
            ls = plot(double(dataObj.time)/1000, dataObj.press_alt_feet, 'Parent', ax);
            
            % Call the data windowing helper to obtain data indices.
            idx = iDAQ.windowdata(ls);
            trimdata(dataObj, idx);  % Trim our internal data
            
            % Update the plot with the windowed data
            plot(double(dataObj.time)/1000, dataObj.press_alt_feet, 'Parent', ax);
        end
        
        
        function fixedwindowtrim(dataObj, windowlength)
            % FIXEDWINDOWTRIM spawns a new figure window and axes object and
            % plots the iDAQ's pressure altitude (feet) vs. time (seconds)
            %
            % A draggable fixed window with length, windowlength, in 
            % seconds, is generated in the axes object, which the user can 
            % drag to choose the time window. If windowlength is not 
            % specified, the default value from the object's private 
            % properties is used. UIWAIT and MSGBOX is used to block MATLAB
            % execution until the user closes the MSGBOX dialog. When 
            % execution resumes, the data indices are used to trim all of
            % the appropriate internal data.
            
            % Spawn new figure window and plot pressure altitude (feet) vs.
            % time (seconds). Because time is stored internally as integer
            % milliseconds from power on, need to convert to a double to
            % avoid integer division and then divide by 1000 to get seconds
            fig = figure;
            ax = axes('Parent', fig);
            ls = plot(double(dataObj.time)/1000, dataObj.press_alt_feet, 'Parent', ax);
            
            % Call the data fixed windowing helper to obtain data indices
            % Check to see if windowlength is provided, if not then we
            % default to the value stored in the object's private
            % properties
            if nargin == 1
                windowlength = dataObj.defaultwindowlength;
            end
            idx = iDAQ.fixedwindowdata(ls, windowlength);
            trimdata(dataObj, idx);  % Trim the internal data
            
            % Update the plot with the windowed data
            plot(double(dataObj.time)/1000, dataObj.press_alt_feet, 'Parent', ax);
        end
        
        
        function trimdata(dataObj, idx)
            % TRIMDATA iterates through all timeseries data stored as
            % properties of the iDAQ object and trims them according to the
            % input data indices. idx is a 1x2 double specifying start and 
            % end indices of the data to retain. All other data is discarded
            
            % Get public properties of our iDAQ object. There are a few
            % properties with data that is not time based, a list of these
            % is stored in our private properties, so we can use this list
            % to exclude them from the data trimming.
            allprops = properties(dataObj);
            propstotrim = allprops(~ismember(allprops, dataObj.propstoignore));
            
            % Iterate through properties to trim and discard data that does
            % not fall between our start and end indices
            for ii = 1:length(propstotrim)
                dataObj.(propstotrim{ii}) = dataObj.(propstotrim{ii})(idx(1):idx(2));
            end
        end
        
        
        function decimate(dataObj, n)
            allprops = properties(dataObj);
            propstotrim = allprops(~ismember(allprops, dataObj.propstoignore));
            
            for ii = 1:length(propstotrim)
                dataObj.(propstotrim{ii}) = dataObj.(propstotrim{ii})(1:(10^n):end);
            end
        end
        
        
        function descentrate = finddescentrate(dataObj)
            % FINDDESCENTRATE Plots the pressure altitude (ft) data and
            % prompts the user to window the region over which to calculate
            % the descent rate. The average descent rate (ft/s and m/s) is 
            % calculated over this windowed region and used to update 
            % the object's descentrate_fps and descentrate_mps properties.
            %
            % descentrate (ft/s) is also an explicit output of this method
            
            % Spawn a new figure window & plot our barometric pressure
            % data to it
            ydata = dataObj.press_alt_feet;
            
            h.fig = figure;
            h.ax = axes;
            h.ls = plot(h.ax, ydata);
            idx = iDAQ.windowdata(h.ls);  % Call data windowing helper to get indices
            
            % Because we just plotted altitude vs. data index, update the
            % plot to altitude vs. time but save the limits and use them so
            % the plot doesn't get zoomed out
            oldxlim = floor(h.ax.XLim);
            oldxlim(oldxlim < 1) = 1;  % Catch indexing issue if plot isn't zoomed "properly"
            oldxlim(oldxlim > length(ydata)) = length(ydata);  % Catch indexing issue if plot isn't zoomed "properly"
            oldylim = h.ax.YLim;
            
            t_seconds = double(dataObj.time)/1000;  % Convert integer milliseconds to seconds
            plot(h.ax, t_seconds, ydata, 'Parent', h.ax);
            xlim(h.ax, t_seconds(oldxlim));
            ylim(h.ax, oldylim);
            
            % Calculate and plot linear fit
            myfit = polyfit(t_seconds(idx(1):idx(2)), ydata(idx(1):idx(2)), 1);
            altitude_feet_fit = t_seconds(idx(1):idx(2))*myfit(1) + myfit(2);
            hold(h.ax, 'on');
            plot(t_seconds(idx(1):idx(2)), altitude_feet_fit, 'r', 'Parent', h.ax)
            hold(h.ax, 'off');
            
            % Set outputs
            descentrate = myfit(1);
            dataObj.descentrate_fps = descentrate;
            dataObj.descentrate_mps = descentrate/3.2808;
        end
        
        
        function save(dataObj, varargin)
            % SAVE saves an instance of the xbmini object to a MAT file. 
            % File is saved in the same directory as the analyzed log file 
            % with the same name as the log.
            %
            % Any existing MAT file of the same name will be overwritten
            p = AirdropData.saveargparse(varargin{:});
            p.FunctionName = 'iDAQ:save';
            
            % Modify the savefilepath if necessary, punt the rest to the
            % super
            if isempty(p.Results.savefilepath)
                [pathname, savefile] = fileparts(dataObj.datafilepath);
                if p.Results.saveasclass
                    savefilepath = iDAQ.sanefilepath(fullfile(pathname, [savefile '_proc.mat']));
                else
                    savefilepath = iDAQ.sanefilepath(fullfile(pathname, [savefile '_proc_noclass.mat']));
                end
            else
                savefilepath = p.Results.savefilepath;
            end
            
            save@AirdropData(savefilepath, dataObj, p.Results.verboseoutput, p.Results.saveasclass)
        end
        
        
        function addID(dataObj, ID)
            % Can probably remove this and just utilize set since we're
            % already inheriting from the handles class
            dataObj.dropID = ID;
        end
    end
    
    
    methods (Access = protected, Hidden)
        function processCSV(dataObj)
            % PROCESSCSV is a helper function for processing the CSV file
            % output by Wamore's iDAQ logdecoder.exe. This helper governs
            % the CSV processing flow.
            
            dataObj.analysisdate = iDAQ.getdate();  % Set analysis date
            
            % Preallocate our data arrays
            dataObj.nlines = iDAQ.countlines(dataObj.datafilepath);
            initializedata(dataObj);
            
            % Parse the CSV data, calculate pressure altitudes, and check
            % for 'bad' CSV data
            parselogCSV(dataObj);
            [dataObj.press_alt_meters, dataObj.press_alt_feet] = iDAQ.calcpress_alt(dataObj.pressure);
            checkCSV(dataObj);
        end
        
        
        function initializedata(dataObj)
            %  INITIALIZEDATA preallocates our data arrays based on the
            %  number of data lines
            dataObj.ndatapoints = dataObj.nlines - dataObj.nheaderlines;
            
            dataObj.time            = zeros(dataObj.ndatapoints, 1, 'uint32');  % Time, milliseconds, since DAQ was powered on
            dataObj.gyro_x          = zeros(dataObj.ndatapoints, 1);  % X gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.gyro_y          = zeros(dataObj.ndatapoints, 1);  % Y gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.gyro_z          = zeros(dataObj.ndatapoints, 1);  % Z gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.accel_x         = zeros(dataObj.ndatapoints, 1);  % X accelerometer output, Gs, with 0.00333 G resolution
            dataObj.accel_y         = zeros(dataObj.ndatapoints, 1);  % Y accelerometer output, Gs, with 0.00333 G resolution
            dataObj.accel_z         = zeros(dataObj.ndatapoints, 1);  % Z accelerometer output, Gs, with 0.00333 G resolution
            dataObj.link_1          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
            dataObj.link_2          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
            dataObj.link_3          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
            dataObj.link_4          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
            dataObj.link_5          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
            dataObj.adc_1           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
            dataObj.adc_2           = zeros(dataObj.ndatapoints, 1);  % On-board 5V supply monitor
            dataObj.adc_3           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
            dataObj.adc_4           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
            dataObj.adc_5           = zeros(dataObj.ndatapoints, 1);  % Approximate battery voltage
            dataObj.adc_6           = zeros(dataObj.ndatapoints, 1);  % On-board 3.3V supply monitor
            dataObj.adc_7           = zeros(dataObj.ndatapoints, 1);  % User input analog voltage #1, 0V to 4.0V
            dataObj.adc_8           = zeros(dataObj.ndatapoints, 1);  % User input analog voltage #2, 0V to 4.0V
            dataObj.adc_temp        = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
            dataObj.din_1           = false(dataObj.ndatapoints, 1);  % Digital input #1 - Lanyard switch status
            dataObj.din_2           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
            dataObj.din_3           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
            dataObj.din_4           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
            dataObj.pwrsw           = false(dataObj.ndatapoints, 1);  % Power switch status: 0-Pressed 1- Open
            dataObj.pstemp          = zeros(dataObj.ndatapoints, 1);  % Temperature reported by the pressure sensor, Celsius
            dataObj.pressure        = zeros(dataObj.ndatapoints, 1);  % Temperature reported by the pressure sensor, Pascals
            dataObj.GPS_Msgs        = zeros(dataObj.ndatapoints, 1);  % Number of NMEA GPS mesages received from the GPS module
            dataObj.GPS_Valid       = cell(dataObj.ndatapoints, 1);   % GPS valid signal: V-Navigation warning A-Valid Data
            dataObj.GPS_Mode        = cell(dataObj.ndatapoints, 1);   % GPS mode: M-Manual A-Automatic
            dataObj.GPS_FixMode     = zeros(dataObj.ndatapoints, 1, 'uint8');  % GPS fix mode; 1-Fix not available 2-2D fix 3-3D fix
            dataObj.GPS_DateTime    = cell(dataObj.ndatapoints, 1);   % GPS date and time, YYYYMMDD-HHMMSS
            dataObj.GPS_SatsInView  = zeros(dataObj.ndatapoints, 1, 'uint8');  % Number of satellites in view
            dataObj.GPS_SatsInUse   = zeros(dataObj.ndatapoints, 1, 'uint8');  % Number of satellites in use
            dataObj.GPS_Latitude    = zeros(dataObj.ndatapoints, 1);  % GPS Latitude, decimal degrees
            dataObj.GPS_Longitude   = zeros(dataObj.ndatapoints, 1);  % GPS Longitude, decimal degrees
            dataObj.GPS_Altitude    = zeros(dataObj.ndatapoints, 1);  % GPS Altitude, meters
            dataObj.GPS_GroundSpeed = zeros(dataObj.ndatapoints, 1);  % GPS Groundspeed, knots true
        end
        
        
        function parselogCSV(dataObj)
            % PARSELOGCSV parses data from the CSV file output by Wamore's
            % iDAQ logdecoder.exe. As a carryover from legacy data, the CSV
            % data is read in by chunks. Historically this was done in the
            % context of 2-stage parachute systems so we could discard all
            % data before the main parachute opened. Because there is
            % a minimal processing time difference, this behavior is
            % retained in case the legacy behavior is desired in the future
            fID = fopen(dataObj.datafilepath);
            
            hlines = dataObj.nheaderlines;
            step = 1;
            while ~feof(fID)
                segarray = textscan(fID, dataObj.formatspec, dataObj.chunksize, 'Delimiter', ',', 'HeaderLines', hlines);
                segarray(22:26) = iDAQ.checkNaN(segarray(22:26));
                hlines = 0; % we've skipped the header line, don't skip more lines on the subsequent imports
                
                if isempty(segarray{:,1})
                    % Temporary workaround for weird reading behavior if Wamore data
                    % has errors in it, forcing script into an infinite loop
                    dataObj.GPS_Altitude    = [dataObj.GPS_Altitude; 1];
                    dataObj.GPS_GroundSpeed = [dataObj.GPS_GroundSpeed; 1];
                    break
                end
                
                idx_start = (step-1)*dataObj.chunksize + 1;
                idx_end = idx_start + length(segarray{:,1}) - 1;
                
                dataObj.time(idx_start:idx_end)            = segarray{1};
                dataObj.gyro_x(idx_start:idx_end)          = segarray{2};
                dataObj.gyro_y(idx_start:idx_end)          = segarray{3};
                dataObj.gyro_z(idx_start:idx_end)          = segarray{4};
                dataObj.accel_x(idx_start:idx_end)         = segarray{5};
                dataObj.accel_y(idx_start:idx_end)         = segarray{6};
                dataObj.accel_z(idx_start:idx_end)         = segarray{7};
                dataObj.link_1(idx_start:idx_end)          = segarray{8};
                dataObj.link_2(idx_start:idx_end)          = segarray{9};
                dataObj.link_3(idx_start:idx_end)          = segarray{10};
                dataObj.link_4(idx_start:idx_end)          = segarray{11};
                dataObj.link_5(idx_start:idx_end)          = segarray{12};
                dataObj.adc_1(idx_start:idx_end)           = segarray{13};
                dataObj.adc_2(idx_start:idx_end)           = segarray{14};
                dataObj.adc_3(idx_start:idx_end)           = segarray{15};
                dataObj.adc_4(idx_start:idx_end)           = segarray{16};
                dataObj.adc_5(idx_start:idx_end)           = segarray{17};
                dataObj.adc_6(idx_start:idx_end)           = segarray{18};
                dataObj.adc_7(idx_start:idx_end)           = segarray{19};
                dataObj.adc_8(idx_start:idx_end)           = segarray{20};
                dataObj.adc_temp(idx_start:idx_end)        = segarray{21};
                dataObj.din_1(idx_start:idx_end)           = segarray{22};
                dataObj.din_2(idx_start:idx_end)           = segarray{23};
                dataObj.din_3(idx_start:idx_end)           = segarray{24};
                dataObj.din_4(idx_start:idx_end)           = segarray{25};
                dataObj.pwrsw(idx_start:idx_end)           = segarray{26};
                dataObj.pstemp(idx_start:idx_end)          = segarray{27};
                dataObj.pressure(idx_start:idx_end)        = segarray{28};
                dataObj.GPS_Msgs(idx_start:idx_end)        = segarray{29};
                dataObj.GPS_Valid(idx_start:idx_end)       = iDAQ.str2cell(segarray{30});
                dataObj.GPS_Mode(idx_start:idx_end)        = iDAQ.str2cell(segarray{31});
                dataObj.GPS_FixMode(idx_start:idx_end)     = segarray{32};
                dataObj.GPS_DateTime(idx_start:idx_end)    = segarray{33};
                dataObj.GPS_SatsInView(idx_start:idx_end)  = segarray{34};
                dataObj.GPS_SatsInUse(idx_start:idx_end)   = segarray{35};
                dataObj.GPS_Latitude(idx_start:idx_end)    = segarray{36};
                dataObj.GPS_Longitude(idx_start:idx_end)   = segarray{37};
                dataObj.GPS_Altitude(idx_start:idx_end)    = segarray{38};
                dataObj.GPS_GroundSpeed(idx_start:idx_end) = segarray{39};
                
                step = step + 1;
            end
            fclose(fID);
        end
        
        
        function checkCSV(dataObj)
            % CHECKSV looks for 'bad' data in the data file output by 
            % Wamore's iDAQ logdecoder.exe. This data is characterized by 
            % zero time entries past the beginning of the data file. If
            % these values are found their corresponding data row is
            % cleared from all time-based data.
            
            % Find any zero time entries
            idx = find(dataObj.time(2:end) <= 0) + 1;
            
            % Get public properties of our iDAQ object. There are a few
            % properties with data that is not time based, a list of these
            % is stored in our private properties, so we can use this list
            % to exclude them from the data trimming.
            allprops = properties(dataObj);
            propstotrim = allprops(~ismember(allprops, dataObj.propstoignore));
            
            % Iterate through properties to trim and discard data that does
            % not fall between our start and end indices
            for ii = 1:length(propstotrim)
                dataObj.(propstotrim{ii})(idx) = [];
            end
        end
    end
    
        
    methods (Static)
        function [CSVpath] = wamoredecoder(filepath)
            % WAMOREDECODER utilizes a system call to Wamore's iDAQ
            % logdecoder.exe to decode the raw iDAQ data. Because
            % logdecoder.exe accepts absolute filepaths, it is assumed that
            % there is a copy of the executable in the same directory as
            % the iDAQ class definition *.m file. An error will be thrown
            % if the executable cannot be found.
            CSVpath = [filepath '.csv'];
            [~, filename, ext] = fileparts(filepath);
            if ~exist(CSVpath, 'file')
                % Identify full path to Wamore's logdecoder executable.
                % For now we'll assume that it's in the same directory as
                % this m-file.
                logdecoderpath = cd;
                if exist(fullfile(logdecoderpath, 'logdecoder.exe'), 'file')
                    fprintf('Decoding ''%s'' ... ', [filename ext])
                    tic
                    systemcall = sprintf('logdecoder.exe "%s"', filepath);
                    [~, cmdout] = system(systemcall);
                    elapsedtime = toc;
                    fprintf('logdecoder.exe finished, elapsed time %.3f seconds\n', elapsedtime)
                else
                    err.identifier = 'iDAQ:wamoredecoder:decodernotfound';
                    err.message = sprintf('Wamore logdecoder.exe not found, please place in ''%s''', logdecoderpath);
                    err.stack = dbstack('-completenames');
                    error(err);
                end
            else
                fprintf('Log file, ''%s'', already decoded. Skipping decoder\n', [filename ext])
            end
        end
        
        
        function [output] = str2cell(chararray)
            % Convert a character array of length N into a Nx1 cell array
            
            N = length(chararray);
            output = cell(N,1);
            
            for ii = 1:N
                output{N} = chararray(N);
            end
        end
        
        
        function [cellarray] = checkNaN(cellarray)
            % Check the digital values from the input for NaNs, set all NaN
            % to false
            for ii = 1:length(cellarray)
                cellarray{ii}(isnan(cellarray{ii})) = 0;
            end
        end
        
        
        function [press_alt_meters, press_alt_feet] = calcpress_alt(pressure)
            % CALCPRESS_ALT maps barometric pressure data to Standard Day 
            % Atmospheric conditions. The pressure lapse rate is used to
            % generate an array to pass to interp1 in order to map the
            % input data to the Standard Atmosphere.
            % Need to revisit to evaluate effect of temperature lapse on calculations
            alt = [-1000:1000:10000 15000:5000:30000];  % Altitude, meters
            press = [1.139e5 1.013e5 8.988e4 7.950e4 7.012e4 6.166e4 5.405e4 4.722e4 4.111e4 3.565e4 3.080e4 2.650e4 1.211e4 5.529e3 2.549e3 1.197e3]; % Pressure, pascals
            press_alt_meters = interp1(press, alt, pressure, 'pchip');  % Pressure altitude, meters
            press_alt_feet   = press_alt_meters * 3.2808;
        end

        
        function batch(filestoparse)
            % Input cell array of full file paths, otherwise leave blank
            % for directory processing
            if nargin == 0
                pathname = uigetdir('Select iDAQ data directory for processing');
                listing = [dir(fullfile(pathname, 'LOG.*')); ...
                           dir(fullfile(pathname, '*.iDAQ'))];
                filestoparse = fullfile(pathname, {listing.name});
            end
            
            for ii = 1:numel(filestoparse)
                tmp = iDAQ(filestoparse{ii});
                verboseoutput = true;
                tmp.save('verboseoutput', verboseoutput)
            end
        end


        function [filepath] = sanefilepath(filepath)
            % Helper to get the right output format for various filenames
            
            % Reformat *.iDAQ filename
            filepath = regexprep(filepath, '\.iDAQ', '');
            
            % Reformat LOG.*
            filepath = regexprep(filepath, '\.(\d*)(?=\_)', '$1');
        end
    end
end

