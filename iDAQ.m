classdef iDAQ < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        filepath_LOG
        filepath_CSV
        filepath_MAT
        analysisdate
        time             % Time, milliseconds, since DAQ was powered on
        gyro_x           % X gyro output, deg/sec, with 0.05 deg/sec resolution
        gyro_y           % Y gyro output, deg/sec, with 0.05 deg/sec resolution
        gyro_z           % Z gyro output, deg/sec, with 0.05 deg/sec resolution
        accel_x          % X accelerometer output, Gs, with 0.00333 G resolution
        accel_y          % Y accelerometer output, Gs, with 0.00333 G resolution
        accel_z          % Z accelerometer output, Gs, with 0.00333 G resolution
        link_1           % Raw strain link ADC data, must be converted to force
        link_2           % Raw strain link ADC data, must be converted to force
        link_3           % Raw strain link ADC data, must be converted to force
        link_4           % Raw strain link ADC data, must be converted to force
        link_5           % Raw strain link ADC data, must be converted to force
        adc_1            % Internal DAQ value, engineering use only
        adc_2            % On-board 5V supply monitor
        adc_3            % Internal DAQ value, engineering use only
        adc_4            % Internal DAQ value, engineering use only
        adc_5            % Approximate battery voltage
        adc_6            % On-board 3.3V supply monitor
        adc_7            % User input analog voltage #1, 0V to 4.0V
        adc_8            % User input analog voltage #2, 0V to 4.0V
        adc_temp         % Internal DAQ value, engineering use only
        din_1            % Digital input #1 - Lanyard switch status
        din_2            % General purpose digital input: 0-Low 1-High
        din_3            % General purpose digital input: 0-Low 1-High
        din_4            % General purpose digital input: 0-Low 1-High
        pwrsw            % Power switch status: 0-Pressed 1- Open
        pstemp           % Temperature reported by the pressure sensor, Celsius
        pressure         % Temperature reported by the pressure sensor, Pascals
        GPS_Msgs         % Number of NMEA GPS mesages received from the GPS module
        GPS_Valid        % GPS valid signal: V-Navigation warning A-Valid Data
        GPS_Mode         % GPS mode: M-Manual A-Automatic
        GPS_FixMode      % GPS fix mode; 1-Fix not available 2-2D fix 3-3D fix
        GPS_DateTime     % GPS date and time, YYYYMMDD-HHMMSS
        GPS_SatsInView   % Number of satellites in view
        GPS_SatsInUse    % Number of satellites in use
        GPS_Latitude     % GPS Latitude, decimal degrees
        GPS_Longitude    % GPS Longitude, decimal degrees
        GPS_Altitude     % GPS Altitude, meters
        GPS_GroundSpeed  % GPS Groundspeed, knots true
    end
    
    properties (Access = private)
        nlines
        nheaderlines = 1;
        ndatapoints
        chunksize = 5000;
        formatspec = '%8u %13.6f %13.6f %13.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %6u %6f %6f %6f %6f %1u %8f %f %8u %c %c %1u %s %3u %3u %f %f %f %f';
    end
    
    methods
        function dataObj = iDAQ(filepath)
            if exist('filepath', 'var')
                filepath = fullfile(filepath);  % Ensure correct file separators
            else
                [file, pathname] = uigetfile({'LOG.*', 'Raw Log File'; ...
                                              '*.csv', 'Decoded Raw Log File'; ...
                                              '*_proc.mat', 'Processed Log File'}, ...
                                             'Select Wamore iDAQ data file' ...
                                              );
                filepath = [pathname file];
            end
            [~, ~, ext] = fileparts(filepath);
            switch ext
                case '.csv'
                    % Parse decoded CSV & process
                    dataObj.filepath_CSV = filepath;
                    dataObj.analysisdate = iDAQ.getdate();
                    dataObj.nlines = iDAQ.countlines(dataObj.filepath_CSV);
                    parselogCSV(dataObj);
                case '.mat'
                    % No parsing needed, dump data straight in
                otherwise
                    % Need to figure out how to best catch LOG.*** files,
                    % catch them here for now
                    % Decode raw data (LOG.***) and process the resulting CSV
                    dataObj.filepath_LOG = filepath;
                    dataObj.analysisdate = iDAQ.getdate();
                    dataObj.filepath_CSV = iDAQ.wamoredecoder(dataObj.filepath_LOG);
                    dataObj.nlines = iDAQ.countlines(dataObj.filepath_CSV);
                    parselogCSV(dataObj);
            end
        end
    end
    
    
    methods (Access = private)
        function initializedata(dataObj)
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
            fID = fopen(dataObj.filepath_CSV);
            
            hlines = dataObj.nheaderlines;
            step = 1;
            while ~feof(fID)
                segarray = textscan(fID, dataObj.formatspec, dataObj.chunksize, 'Delimiter', ',', 'HeaderLines', hlines);
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
    end
    
        
    methods (Static)
        function date = getdate()
            if ~verLessThan('MATLAB', '8.4')  % datetime added in R2014b
                timenow = datetime('now', 'TimeZone', 'local');
                formatstr = sprintf('yyyy-mm-ddTHH:MM:SS%sZ', char(tzoffset(timenow)));
            else
                UTCoffset = -java.util.Date().getTimezoneOffset/60;  % See what Java thinks your TZ offset is
                timenow = clock;
                formatstr = sprintf('yyyy-mm-ddTHH:MM:SS%i:00Z', UTCoffset);
            end
            
            date = datestr(timenow, formatstr);  % ISO 8601 format
        end
        
        
        function nlines = countlines(filepath)
            % Count the number of lines present in the specified file.
            % filepath should be an absolute path
            
            filepath = fullfile(filepath);  % Make sure we're using the correct OS file separators
            
            % Attempt to use system specific calls, otherwise use MATLAB
            if ispc
                syscall = sprintf('find /v /c "" "%s"', filepath);
                [~, cmdout] = system(syscall);
                tmp = regexp(cmdout, '(?<=(:\s))(\d*)', 'match');
                nlines = str2double(tmp{1});
            elseif ismac || isunix
                syscall = sprintf('wc -l < "%s"', filepath);
                [~, cmdout] = system(syscall);
                nlines = str2double(cmdout);
            else
                % Can't determine OS, use MATLAB instead
                fID = fopen(filepath, 'rt');
                
                nlines = 0;
                while ~feof(fID)
                    nlines = nlines + sum(fread(fID, 16384, 'char') == char(10));
                end
                
                fclose(fID);
            end
        end
        
        
        function [CSVpath] = wamoredecoder(filepath)
            [pathname, filename, ext] = fileparts(filepath);
            startdir = cd(pathname);
            file = [filename, ext];
            CSVpath = [file '.csv'];
            if ~exist(CSVpath, 'file')
                fprintf('Decoding Log %s ... ', regexprep(ext, '\.', ''))
                tic
                [~, cmdout] = dos(['logdecoder.exe ' file]);
                elapsedtime = toc;
                fprintf('logdecoder.exe exited, elapsed time %.3f seconds\n', elapsedtime)
                cd(startdir)
            else
                fprintf('Log %s already decoded, skipping decoder\n', regexprep(ext, '\.', ''))
                cd(startdir)
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
    end
    
end
