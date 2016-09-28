classdef iDAQ < handle
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
    %     save            - Save the current iDAQ class instance
    %     savemat         - Save the loaded iDAQ data to a MAT file
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

%         link_1            % Raw strain link ADC data, must be converted to force
%         link_2            % Raw strain link ADC data, must be converted to force
%         link_3            % Raw strain link ADC data, must be converted to force
%         link_4            % Raw strain link ADC data, must be converted to force
%         link_5            % Raw strain link ADC data, must be converted to force
%         adc_1             % Internal DAQ value, engineering use only
%         adc_2             % On-board 5V supply monitor
%         adc_3             % Internal DAQ value, engineering use only
%         adc_4             % Internal DAQ value, engineering use only
%         adc_5             % Approximate battery voltage
%         adc_6             % On-board 3.3V supply monitor
%         adc_7             % User input analog voltage #1, 0V to 4.0V
%         adc_8             % User input analog voltage #2, 0V to 4.0V
%         adc_temp          % Internal DAQ value, engineering use only
%         din_1             % Digital input #1 - Lanyard switch status
%         din_2             % General purpose digital input: 0-Low 1-High
%         din_3             % General purpose digital input: 0-Low 1-High
%         din_4             % General purpose digital input: 0-Low 1-High
%         pwrsw             % Power switch status: 0-Pressed 1- Open

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
        formatspec = '%8u %13.6f %13.6f %13.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %6u %6f %6f %6f %6f %1u %8f %f %8u %c %c %1u %s %3u %3u %f %f %f %f';
        propstoignore = {'datafilepath', 'analysisdate', 'dropID', 'descentrate_fps', 'descentrate_mps'};  % Properties to ignore during data trimming
        defaultwindowlength = 12;  % Default data windowing length, seconds
    end
    
    methods
        function dataObj = iDAQ(filepath)
            % iDAQ Class Constructor
            
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
                    % Assume a saved instance of the iDAQ class, so this
                    % can be loaded in directly
                    
                    % See if we have a saved instance of this class
                    matfileinfo = whos('-file', filepath);
                    iDAQtest = strcmp({matfileinfo(:).class}, 'iDAQ');
                    if any(iDAQtest)
                        % Only use first instance of an iDAQ class instance
                        varidx = find(iDAQtest, 1);
                        tmp = load(filepath, matfileinfo(varidx).name);
                        dataObj = tmp.(matfileinfo(varidx).name);  % Pull the object out of the structure
                    else
                        % No iDAQ class instances, error out
                        % Eventually we'll want to check for the bare *.mat
                        % files here
                        err.identifier = 'iDAQ:wamoredecoder:unsupportedMATfile';
                        err.message = sprintf('MAT file, ''%s'', does not contain any supported variables\n', filepath);
                        err.stack = dbstack('-completenames');
                        error(err);
                    end
                case '.iDAQ'
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
            figure
            ls = plot(double(dataObj.time)/1000, dataObj.press_alt_feet);
            
            idx = iDAQ.windowdata(ls);
            trimdata(dataObj, idx);
            
            plot(double(dataObj.time)/1000, dataObj.press_alt_feet);
        end
        
        
        function fixedwindowtrim(dataObj, windowlength)
            figure
            ls = plot(double(dataObj.time)/1000, dataObj.press_alt_feet);
            
            if nargin == 1
                windowlength = dataObj.defaultwindowlength;
            end
            idx = iDAQ.fixedwindowdata(ls, windowlength);
            trimdata(dataObj, idx);
            
            plot(double(dataObj.time)/1000, dataObj.press_alt_feet);
        end
        
        
        function trimdata(dataObj, idx)
            allprops = properties(dataObj);
            propstotrim = allprops(~ismember(allprops, dataObj.propstoignore));
            
            for ii = 1:length(propstotrim)
                dataObj.(propstotrim{ii}) = dataObj.(propstotrim{ii})(idx(1):idx(2));
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
            oldylim = ax.YLim;
            
            t_seconds = double(dataObj.time)/1000;  % Convert integer milliseconds to seconds
            plot(ax, t_seconds, ydata, 'Parent', ax);
            xlim(ax, t_seconds(oldxlim));
            ylim(ax, oldylim);
            
            % Calculate and plot linear fit
            myfit = polyfit(t_seconds(idx(1):idx(2)), ydata(idx(1):idx(2)), 1);
            altitude_feet_fit = t_seconds(idx(1):idx(2))*myfit(1) + myfit(2);
            hold(ax, 'on');
            plot(t_seconds(idx(1):idx(2)), altitude_feet_fit, 'r', 'Parent', ax)
            hold(ax, 'off');
            
            % Set outputs
            descentrate = myfit(1);
            dataObj.descentrate_fps = descentrate;
            dataObj.descentrate_mps = descentrate/3.2808;
        end
        
        
        function savemat(dataObj, isverbose)
            % SAVEMAT Saves a copy of the iDAQ class instance's public 
            % properties to a MAT file as a vanilla data structure that
            % doesn't require the class definition to load into MATLAB.
            %
            % MAT file is saved to the same directory as the analyzed data
            % file
            %
            % Accepts an optional isverbose boolean value to specify
            % whether or not to display a message on save
            
            % Get property names and use them to loop through using dynamic
            % field referencing
            allprops = properties(dataObj);
            for ii = 1:length(allprops);
                output.(allprops{ii}) = dataObj.(allprops{ii});
            end
            output.datafilepath = dataObj.datafilepath;
            
            % Save our file in the same directory as the analyzed data
            [pathname, savefile] = fileparts(dataObj.datafilepath);
            % Use helper to fix filename readability
            savefilepath = iDAQ.sanefilepath(fullfile(pathname, [savefile '_proc_noclass.mat']));
            save(savefilepath, 'output');
            
            % Print status message if we've passed isverbose as true
            if nargin == 2
                if isverbose
                    fprintf('Bare *.mat file saved to ''%s''\n', savefilepath);
                end
            end
        end
        
        
        function save(dataObj, isverbose)
            % SAVE Saves the current instance of the iDAQ object to a MAT
            % file. Loading data from this MAT file will require the iDAQ
            % class definition be present in MATLAB's path.
            %
            % MAT file is saved to the same directory as the analyzed data
            % file
            %
            % Accepts an optional isverbose boolean value to specify
            % whether or not to display a message on save
            
            % Save our file in the same directory as the analyzed data
            [pathname, savefile] = fileparts(dataObj.datafilepath);
            % Use helper to fix filename readability
            savefilepath = iDAQ.sanefilepath(fullfile(pathname, [savefile '_proc.mat']));
            save(savefilepath, 'dataObj');
            
            % Print status message if we've passed isverbose as true
            if nargin == 2
                if isverbose
                    fprintf('iDAQ class instance saved to ''%s''\n', savefilepath);
                end
            end
        end
        
        
        function addID(dataObj, ID)
            dataObj.dropID = ID;
        end
    end
    
    
    methods (Access = private)
        function processCSV(dataObj)
            dataObj.analysisdate = iDAQ.getdate();
            dataObj.nlines = iDAQ.countlines(dataObj.datafilepath);
            initializedata(dataObj);
            parselogCSV(dataObj);
            [dataObj.press_alt_meters, dataObj.press_alt_feet] = iDAQ.calcpress_alt(dataObj.pressure);
            checkCSV(dataObj);
        end
        
        
        function initializedata(dataObj)
            dataObj.ndatapoints = dataObj.nlines - dataObj.nheaderlines;
            
            dataObj.time            = zeros(dataObj.ndatapoints, 1, 'uint32');  % Time, milliseconds, since DAQ was powered on
            dataObj.gyro_x          = zeros(dataObj.ndatapoints, 1);  % X gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.gyro_y          = zeros(dataObj.ndatapoints, 1);  % Y gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.gyro_z          = zeros(dataObj.ndatapoints, 1);  % Z gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.accel_x         = zeros(dataObj.ndatapoints, 1);  % X accelerometer output, Gs, with 0.00333 G resolution
            dataObj.accel_y         = zeros(dataObj.ndatapoints, 1);  % Y accelerometer output, Gs, with 0.00333 G resolution
            dataObj.accel_z         = zeros(dataObj.ndatapoints, 1);  % Z accelerometer output, Gs, with 0.00333 G resolution
%             dataObj.link_1          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_2          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_3          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_4          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_5          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.adc_1           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.adc_2           = zeros(dataObj.ndatapoints, 1);  % On-board 5V supply monitor
%             dataObj.adc_3           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.adc_4           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.adc_5           = zeros(dataObj.ndatapoints, 1);  % Approximate battery voltage
%             dataObj.adc_6           = zeros(dataObj.ndatapoints, 1);  % On-board 3.3V supply monitor
%             dataObj.adc_7           = zeros(dataObj.ndatapoints, 1);  % User input analog voltage #1, 0V to 4.0V
%             dataObj.adc_8           = zeros(dataObj.ndatapoints, 1);  % User input analog voltage #2, 0V to 4.0V
%             dataObj.adc_temp        = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.din_1           = false(dataObj.ndatapoints, 1);  % Digital input #1 - Lanyard switch status
%             dataObj.din_2           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
%             dataObj.din_3           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
%             dataObj.din_4           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
%             dataObj.pwrsw           = false(dataObj.ndatapoints, 1);  % Power switch status: 0-Pressed 1- Open
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
%                 dataObj.link_1(idx_start:idx_end)          = segarray{8};
%                 dataObj.link_2(idx_start:idx_end)          = segarray{9};
%                 dataObj.link_3(idx_start:idx_end)          = segarray{10};
%                 dataObj.link_4(idx_start:idx_end)          = segarray{11};
%                 dataObj.link_5(idx_start:idx_end)          = segarray{12};
%                 dataObj.adc_1(idx_start:idx_end)           = segarray{13};
%                 dataObj.adc_2(idx_start:idx_end)           = segarray{14};
%                 dataObj.adc_3(idx_start:idx_end)           = segarray{15};
%                 dataObj.adc_4(idx_start:idx_end)           = segarray{16};
%                 dataObj.adc_5(idx_start:idx_end)           = segarray{17};
%                 dataObj.adc_6(idx_start:idx_end)           = segarray{18};
%                 dataObj.adc_7(idx_start:idx_end)           = segarray{19};
%                 dataObj.adc_8(idx_start:idx_end)           = segarray{20};
%                 dataObj.adc_temp(idx_start:idx_end)        = segarray{21};
%                 dataObj.din_1(idx_start:idx_end)           = segarray{22};
%                 dataObj.din_2(idx_start:idx_end)           = segarray{23};
%                 dataObj.din_3(idx_start:idx_end)           = segarray{24};
%                 dataObj.din_4(idx_start:idx_end)           = segarray{25};
%                 dataObj.pwrsw(idx_start:idx_end)           = segarray{26};
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
            % Check for zero time entries past the beginning of the data
            % file and clear them.
            idx = find(dataObj.time(2:end) <= 0) + 1;
            allprops = properties(dataObj);
            propstotrim = allprops(~ismember(allprops, dataObj.propstoignore));
            
            for ii = 1:length(propstotrim)
                dataObj.(propstotrim{ii})(idx) = [];
            end
        end
    end
    
        
    methods (Static)
        function date = getdate()
            % Generate current local timestamp and format according to
            % ISO 8601: yyyy-mm-ddTHH:MM:SS+/-HH:MMZ
            if ~verLessThan('MATLAB', '8.4')  % datetime added in R2014b
                timenow = datetime('now', 'TimeZone', 'local');
                formatstr = sprintf('yyyy-mm-ddTHH:MM:SS%sZ', char(tzoffset(timenow)));
            else
                UTCoffset = -java.util.Date().getTimezoneOffset/60;  % See what Java thinks your TZ offset is
                timenow = clock;
                formatstr = sprintf('yyyy-mm-ddTHH:MM:SS%i:00Z', UTCoffset);
            end
            
            date = datestr(timenow, formatstr);
        end
        
        
        function nlines = countlines(filepath)
            % COUNTLINES counts the number of lines present in the 
            % specified file, filepath, passed as an absolute path.
            % COUNTLINES attempts to utilize OS specific calls but utilizes
            % MATLAB's built-ins as a fallback.
            
            % Attempt to use system specific calls, otherwise use MATLAB
            if ispc
                syscall = sprintf('find /v /c "" "%s"', filepath);  % Count lines in file
                [~, cmdout] = system(syscall);
                % cmdout is of form: ---------- filepath: nlines
                % We can parse this with a regex that searches for 1 or
                % more digits anchored by a colon + whitespace
                tmp = regexp(cmdout, '(?<=(:\s))(\d*)', 'match');
                nlines = str2double(tmp{1});
            elseif ismac || isunix
                syscall = sprintf('wc -l < "%s"', filepath);
                [~, cmdout] = system(syscall);
                % wc -l returns number of lines directly
                nlines = str2double(cmdout);
            else
                % Can't determine OS, use MATLAB instead
                fID = fopen(filepath, 'rt');
                
                blocksize = 16384;  % Size of block to read in, bytes
                nlines = 0;
                while ~feof(fID)
                    % Read in CSV file as binary file in chunks, count the
                    % number of line feed characters (ASCII 10)
                    nlines = nlines + sum(fread(fID, blocksize, 'char') == char(10));
                end
                
                fclose(fID);
            end
        end
        
        
        function [CSVpath] = wamoredecoder(filepath)
            CSVpath = [filepath '.csv'];
            [~, filename, ext] = fileparts(filepath);
            if ~exist(CSVpath, 'file')
                % Identify full path to Wamore's logdecoder executable.
                % For now we'll assume that it's in the same directory as
                % this m-file.
                % Once AppLocker goes live on the DREN we will need to
                % point to a whitelisted folder in order to decode iDAQ
                % data.
                logdecoderpath = cd;
                if exist(fullfile(logdecoderpath, 'logdecoder.exe'), 'file')
                    fprintf('Decoding ''%s'' ... ', [filename ext])
                    tic
                    systemcall = sprintf('logdecoder.exe "%s"', filepath);
                    [~, cmdout] = system(systemcall);
                    elapsedtime = toc;
                    fprintf('logdecoder.exe exited, elapsed time %.3f seconds\n', elapsedtime)
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
            % Determine altitude based on pressure
            % Need to revisit to evaluate effect of temperature lapse on calculations
            alt = [-1000:1000:10000 15000:5000:30000];  % Altitude, meters
            press = [1.139e5 1.013e5 8.988e4 7.950e4 7.012e4 6.166e4 5.405e4 4.722e4 4.111e4 3.565e4 3.080e4 2.650e4 1.211e4 5.529e3 2.549e3 1.197e3]; % Pressure, pascals
            press_alt_meters = interp1(press, alt, pressure, 'pchip');  % Pressure altitude, meters
            press_alt_feet   = press_alt_meters * 3.2808;
        end
        
        
        function [dataidx] = windowdata(ls, waitboxBool)
            % TODO: Update this inline documentation
            
            % WINDOWDATA plots the input data array, ydata, with respect to
            % its data indices along with two vertical lines for the user 
            % to window the plotted data. 
            % 
            % Execution is blocked by UIWAIT and MSGBOX to allow the user 
            % to zoom/pan the axes and manipulate the window lines as 
            % desired. Once the dialog is closed the data indices of the 
            % window lines, dataidx, and handle to the axes are returned.
            %
            % Because ydata is plotted with respect to its data indices,
            % the indices are floored to the nearest integer in order to
            % mitigate indexing issues.
            ax = ls.Parent;
            fig = ax.Parent;
            fig.WindowButtonUpFcn = @iDAQ.stopdrag;  % Set the mouse button up Callback on figure creation
            
            % Create our window lines, set the default line X locations at
            % 25% and 75% of the axes limits
            currxlim = xlim(ax);
            axeswidth = currxlim(2) - currxlim(1);
            dragline(1) = line(ones(1, 2)*axeswidth*0.25, ylim(ax), ...
                            'Color', 'g', 'ButtonDownFcn', @(s,e)iDAQ.startdrag(s, ax));
            dragline(2) = line(ones(1, 2)*axeswidth*0.75, ylim(ax), ...
                            'Color', 'g', 'ButtonDownFcn', @(s,e)iDAQ.startdrag(s, ax));
            
            % Add appropriate listeners to the X and Y axes to ensure
            % window lines are visible and the appropriate height
            xlisten = addlistener(ax, 'XLim', 'PostSet', @(s,e)iDAQ.checklinesx(ax, dragline));
            ylisten = addlistener(ax, 'YLim', 'PostSet', @(s,e)iDAQ.changelinesy(ax, dragline));
            
            % Unless passed a secondary, False argument, use uiwait to 
            % allow the user to manipulate the axes and window lines as 
            % desired. Otherwise it is assumed that uiresume is called
            % elsewhere to unblock execution
            if nargin == 2 && ~waitboxBool
                uiwait
            else
                uiwait(msgbox('Window Region of Interest Then Press OK'))
            end
            
            % Set output
            dataidx(1) = find(ls.XData >= dragline(1).XData(1), 1);
            dataidx(2) = find(ls.XData >= dragline(2).XData(1), 1);
            dataidx = sort(dataidx);
            
            % Clean up
            delete([xlisten, ylisten]);
            delete(dragline)
            fig.WindowButtonUpFcn = '';
        end


        function [dataidx] = fixedwindowdata(ls, windowlength, waitboxBool)
            ax = ls.Parent;
            fig = ax.Parent;
            fig.WindowButtonUpFcn = @iDAQ.stopdrag;  % Set the mouse button up Callback on figure creation
            
            currxlim = xlim(ax);
            currylim = ylim(ax);
            axeswidth = currxlim(2) - currxlim(1);

            leftx = axeswidth*0.25;
            rightx = leftx + windowlength;
            vertices = [leftx, currylim(1); ...   % Bottom left corner
                        rightx, currylim(1); ...  % Bottom right corner
                        rightx, currylim(2); ...  % Top right corner
                        leftx, currylim(2)];      % Top left corner
            dragpatch = patch('Vertices', vertices, 'Faces', [1 2 3 4], ...
                                'FaceColor', 'green', 'FaceAlpha', 0.3, ...
                                'ButtonDownFcn', {@iDAQ.startdragwindow, ax});
            
            % Unless passed a tertiary, False argument, use uiwait to 
            % allow the user to manipulate the axes and window lines as 
            % desired. Otherwise it is assumed that uiresume is called
            % elsewhere to unblock execution
            if nargin == 3 && ~waitboxBool
                uiwait
            else
                uiwait(msgbox('Window Region of Interest Then Press OK'))
            end
            
            % Set output
            dataidx(1) = find(ls.XData >= dragpatch.XData(1), 1);
            dataidx(2) = find(ls.XData >= dragpatch.XData(2), 1);
            dataidx = sort(dataidx);
            
            % Clean up
            delete(dragpatch)
            fig.WindowButtonUpFcn = '';
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
                tmp.save(verboseoutput)
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
    
    
    methods (Static, Access = private)
        function startdrag(lineObj, ax)
            % Helper function for data windowing, sets figure
            % WindowButtonMotionFcn callback to dragline helper
            % while line is being clicked on & dragged
            ax.Parent.WindowButtonMotionFcn = @(s,e)iDAQ.linedrag(h, lineObj);
        end
        
        
        function stopdrag(hObj, ~)
            % Helper function for data windowing, clears figure window
            % WindowButtonMotionFcn callback when mouse button is released
            % after dragging the line
            hObj.WindowButtonMotionFcn = '';
        end
        
        
        function checklinesx(ax, dragline)
            % Helper function for data windowing, checks the X indices of
            % the vertical lines to make sure they're still within the X
            % axis limits of the data axes object
            currxlim = ax.XLim;
            currlinex(1) = dragline(1).XData(1);
            currlinex(2) = dragline(2).XData(1);
            
            % Set X coordinate of any line outside the axes limits to the
            % axes limit
            if currlinex(1) < currxlim(1)
                dragline(1).XData = [1, 1]*currxlim(1);
            end
            
            if currlinex(1) > currxlim(2)
                dragline(1).XData = [1, 1]*currxlim(2);
            end
            
            if currlinex(2) < currxlim(1)
                dragline(2).XData = [1, 1]*currxlim(1);
            end
            
            if currlinex(2) > currxlim(2)
               dragline(2).XData = [1, 1]*currxlim(2);
            end
            
        end
        
        
        function changelinesy(~, ~, h)
            % Helper function for data windowing, sets the height of both
            % vertical lines to the height of the axes object
            h.line_1.YData = ylim(h.ax);
            h.line_2.YData = ylim(h.ax);
        end

        
        function linedrag(h, lineObj)
            % Helper function for data windowing, updates the x coordinate
            % of the dragged line to the current location of the mouse
            % button
            currentX = h.ax.CurrentPoint(1, 1);
            
            % Prevent dragging outside of the current axes limits
            if currentX < h.ax.XLim(1)
                lineObj.XData = [1, 1]*h.ax.XLim(1);
            elseif currentX > h.ax.XLim(2)
                lineObj.XData = [1, 1]*h.ax.XLim(2);
            else
                lineObj.XData = [1, 1]*currentX;
            end
        end
        
        function startdragwindow(patchObj, ed, ax)
            ax.Parent.WindowButtonMotionFcn = @(s,e)iDAQ.dragwindow(ax, patchObj);
            patchObj.UserData = ed.IntersectionPoint(1);  % Store initial click location to find a delta later
        end
        
        
        function dragwindow(ax, patchObj)
            oldmouseX = patchObj.UserData;
            newmouseX = ax.CurrentPoint(1);
            patchObj.UserData = newmouseX;
            
            dx = newmouseX - oldmouseX;
            newpatchX = patchObj.XData + dx; 
            
            % Prevent dragging outside of the current axes limits
            if newpatchX(1) < ax.XLim(1)
                newdx = patchObj.XData - ax.XLim(1);
                patchObj.XData = patchObj.XData + newdx;
            elseif newpatchX(2) > ax.XLim(2)
                newdx = patchObj.XData - ax.XLim(2);
                patchObj.XData = patchObj.XData + newdx;
            else
                patchObj.XData = newpatchX;
            end
        end
    end
end

