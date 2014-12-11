function [varargout] = WamoreDataBox_AllData_NoIMU(filepath)
% Load in data from Wamore data box
% As the data sets are often large due to the 1,000Hz sampling rate writing
% 39 columns of data, the file is parsed into 5,000 block segments and
% read in individually. Once conditions have been identified, the
% application terminates reading, leaving only the useful data to process.
%
% If the full path to a file is not specified the user will be prompted

try
    file_id = fopen(filepath);
    [pathname,~,~] = fileparts(filepath);
catch
    [file,pathname] = uigetfile('*.csv','Select a Wamore Log file (*.csv)');
    filepath = [pathname file];
    
    file_id = fopen(filepath);
end

tic

% Count number of lines in log file to preallocate the data arrays
% Write the pearl script if it isn't present
try
    n_rows = str2double(perl('countlines.pl',filepath)) - 1;
catch
    disp('Pearl script not found, creating and adding to current working directory')
    temp_fid = fopen('countlines.pl','w+');
    line1 = 'while (<>){};';
    line2 = 'print $.,"\n"';
    fprintf(temp_fid,'%s\n%s',line1,line2);
    fclose(temp_fid); 
    clear line1 line2
    n_rows = str2double(perl('countlines.pl',filepath)) - 1;
end

chunksize = 5000;

hlines = 1; % used to skip the first line when we begin importing data
format = '%8u %13.6f %13.6f %13.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f %6u %6f %6f %6f %6f %1u %8f %f %8u %c %c %1u %s %3u %3u %f %f %f %f';

output.t               = zeros(n_rows,1); % Time, milliseconds, since DAQ was powered on
output.xgyro           = zeros(n_rows,1); % X gyro output, deg/sec, with 0.05 deg/sec resolution
output.ygyro           = zeros(n_rows,1); % Y gyro output, deg/sec, with 0.05 deg/sec resolution
output.zgyro           = zeros(n_rows,1); % Z gyro output, deg/sec, with 0.05 deg/sec resolution
output.xaccl           = zeros(n_rows,1); % X accelerometer output, Gs, with 0.00333 G resolution
output.yaccl           = zeros(n_rows,1); % Y accelerometer output, Gs, with 0.00333 G resolution
output.zaccl           = zeros(n_rows,1); % Z accelerometer output, Gs, with 0.00333 G resolution
% output.link1           = zeros(n_rows,1); % Raw strain link ADC data, must be converted to force
% output.link2           = zeros(n_rows,1); % Raw strain link ADC data, must be converted to force
% output.link3           = zeros(n_rows,1); % Raw strain link ADC data, must be converted to force
% output.link4           = zeros(n_rows,1); % Raw strain link ADC data, must be converted to force
% output.link5           = zeros(n_rows,1); % Raw strain link ADC data, must be converted to force
% output.adc1            = zeros(n_rows,1); % Internal DAQ value, engineering use only
% output.adc2            = zeros(n_rows,1); % On-board 5V supply monitor
% output.adc3            = zeros(n_rows,1); % Internal DAQ value, engineering use only
% output.adc4            = zeros(n_rows,1); % Internal DAQ value, engineering use only
% output.adc5            = zeros(n_rows,1); % Approximate battery voltage
% output.adc6            = zeros(n_rows,1); % On-board 3.3V supply monitor
% output.adc7            = zeros(n_rows,1); % User input analog voltage #1, 0V to 4.0V
% output.adc8            = zeros(n_rows,1); % User input analog voltage #2, 0V to 4.0V
% output.adctemp         = zeros(n_rows,1); % Internal DAQ value, engineering use only
% output.din1            = zeros(n_rows,1); % Digital input #1 - Lanyard switch status
% output.din2            = zeros(n_rows,1); % General purpose digital input: 0-Low 1-High
% output.din3            = zeros(n_rows,1); % General purpose digital input: 0-Low 1-High
% output.din4            = zeros(n_rows,1); % General purpose digital input: 0-Low 1-High
% output.pwrsw           = zeros(n_rows,1); % Power switch status: 0-Pressed 1- Open
output.pstemp          = zeros(n_rows,1); % Temperature reported by the pressure sensor, Celsius
output.pressure        = zeros(n_rows,1); % Temperature reported by the pressure sensor, Pascals
% output.GPS.Msgs        = zeros(n_rows,1); % Number of NMEA GPS mesages received from the GPS module
% output.GPS.Valid       = cell(n_rows,1);  % GPS valid signal: V-Navigation warning A-Valid Data
% output.GPS.Mode        = cell(n_rows,1);  % GPS mode: M-Manual A-Automatic
output.GPS.FixMode     = zeros(n_rows,1); % GPS fix mode; 1-Fix not available 2-2D fix 3-3D fix
output.GPS.DateTime    = cell(n_rows,1);  % GPS date and time, YYYYMMDD-HHMMSS
output.GPS.SatsInView  = zeros(n_rows,1); % Number of satellites in view
output.GPS.SatsInUse   = zeros(n_rows,1); % Number of satellites in use
output.GPS.Latitude    = zeros(n_rows,1); % GPS Latitude, decimal degrees
output.GPS.Longitude   = zeros(n_rows,1); % GPS Longitude, decimal degrees
output.GPS.Altitude    = zeros(n_rows,1); % GPS Altitude, meters
output.GPS.GroundSpeed = zeros(n_rows,1); % GPS Groundspeed, knots true

frewind(file_id);
step = 1;
while ~feof(file_id)
    segarray = textscan(file_id, format, chunksize, 'Delimiter',',','HeaderLines',hlines);
    hlines = 0; % we've skipped the header line, don't skip more lines on the subsequent imports
    
    if isempty(segarray{:,1})
        % Temporary workaround for weird reading behavior if wamore data 
        % has errors in it, forcing script into an infinite loop
        output.GPS.Altitude    = [output.GPS.Altitude; 1];
        output.GPS.GroundSpeed = [output.GPS.GroundSpeed; 1];
        break
    end
        
    idx_start = (step-1)*chunksize + 1;
    idx_end = idx_start + length(segarray{:,1}) - 1;
    
    output.t(idx_start:idx_end)               = segarray{1};
    output.xgyro(idx_start:idx_end)           = segarray{2};
    output.ygyro(idx_start:idx_end)           = segarray{3};
    output.zgyro(idx_start:idx_end)           = segarray{4};
    output.xaccl(idx_start:idx_end)           = segarray{5};
    output.yaccl(idx_start:idx_end)           = segarray{6};
    output.zaccl(idx_start:idx_end)           = segarray{7};
%     output.link1(idx_start:idx_end)           = segarray{8};
%     output.link2(idx_start:idx_end)           = segarray{9};
%     output.link3(idx_start:idx_end)           = segarray{10};
%     output.link4(idx_start:idx_end)           = segarray{11};
%     output.link5(idx_start:idx_end)           = segarray{12};
%     output.adc1(idx_start:idx_end)            = segarray{13};
%     output.adc2(idx_start:idx_end)            = segarray{14};
%     output.adc3(idx_start:idx_end)            = segarray{15};
%     output.adc4(idx_start:idx_end)            = segarray{16};
%     output.adc5(idx_start:idx_end)            = segarray{17};
%     output.adc6(idx_start:idx_end)            = segarray{18};
%     output.adc7(idx_start:idx_end)            = segarray{19};
%     output.adc8(idx_start:idx_end)            = segarray{20};
%     output.adctemp(idx_start:idx_end)         = segarray{21};
%     output.din1(idx_start:idx_end)            = segarray{22};
%     output.din2(idx_start:idx_end)            = segarray{23};
%     output.din3(idx_start:idx_end)            = segarray{24};
%     output.din4(idx_start:idx_end)            = segarray{25};
%     output.pwrsw(idx_start:idx_end)           = segarray{26};
    output.pstemp(idx_start:idx_end)          = segarray{27};
    output.pressure(idx_start:idx_end)        = segarray{28};
%     output.GPS.Msgs(idx_start:idx_end)        = segarray{29};
%     output.GPS.Valid(idx_start:idx_end)       = str2cell(segarray{30});
%     output.GPS.Mode(idx_start:idx_end)        = str2cell(segarray{31});
    output.GPS.FixMode(idx_start:idx_end)     = segarray{32};
    output.GPS.DateTime(idx_start:idx_end)    = segarray{33};
    output.GPS.SatsInView(idx_start:idx_end)  = segarray{34};
    output.GPS.SatsInUse(idx_start:idx_end)   = segarray{35};
    output.GPS.Latitude(idx_start:idx_end)    = segarray{36};
    output.GPS.Longitude(idx_start:idx_end)   = segarray{37};
    output.GPS.Altitude(idx_start:idx_end)    = segarray{38};
    output.GPS.GroundSpeed(idx_start:idx_end) = segarray{39};
    
    step = step+1;
end

fclose(file_id);

output.press_alt = calcpressalt(output.pressure);

if exist([pathname filesep 'Jumper_Info.txt'],'file')
    [output.canopytype,output.AUW] = pulljumpdata(pathname);
end

[~,savefile,~] = fileparts(filepath);
savefile(savefile=='.') = ''; % Clear out periods

save([pathname filesep savefile '_proc.mat'],'output');
% writeexcelfile(output,pathname,savefile);
% writecsvdata(output,pathname,savefile);
% exportplot(output,pathname,savefile);
% sonde_windcorrect(output,pathname,savefile);

toc

if nargout ~= 0
    varargout{1} = output;
end

end

function [output] = str2cell(chararray)
% Converts a character array of length N into a Nx1 cell array to fix
% results of the %c field specifier in textscan

N = length(chararray);
output = cell(N,1);

for ii = 1:N
    output{N} = chararray(N);
end

end

function [press_alt] = calcpressalt(pressure)
% determine altitude based on pressure
% Need to revisit to evaluate effect of temperature lapse on calculations
alt = [-1000:1000:10000 15000:5000:30000]; % altitude, meters
press = [1.139e5 1.013e5 8.988e4 7.950e4 7.012e4 6.166e4 5.405e4 4.722e4 4.111e4 3.565e4 3.080e4 2.650e4 1.211e4 5.529e3 2.549e3 1.197e3]; % Pressure, pascals
press_alt = interp1(press,alt,pressure,'pchip'); % pressure altitude, meters
end

function [canopytype,AUW] = pulljumpdata(pathname)
fID = fopen([pathname filesep 'Jumper_Info.txt']);
temp = cell(2,2);
ii = 1;
while ~feof(fID)
    temp(ii,1:2) = strsplit(fgetl(fID),',');
    ii = ii+1;
end
fclose(fID);
canopytype = temp{1,2};
AUW        = temp{2,2};
end

function writeexcelfile(output,pathname,savefile)
% Not the most robust implementation, revisit later to fix unnecessary
% overhead from splitting off the vectors.
output_headers = { ...
    'time (ms)', ...
    'Latitude (dec deg)', ...
    'Longitude (dec deg)', ...
    'GPS Alt. (meters)', ...
    'GPS Groundspeed (meters/sec)', ...
    'Raw Baro Pressure (Pascals)' ...
    };

% Decimate output down to 10 Hz
% Start where GPS locks

test = find(output.GPS.Latitude~=0); t_start_idx = test(1); clear test; % Find start of data and pull index
new_t = output.t(t_start_idx):100:output.t(end);
to_excel = zeros(length(new_t),length(output_headers));

to_excel(:,1) = new_t;
to_excel(:,2) = interp1(output.t,output.GPS.Latitude,new_t);
to_excel(:,3) = interp1(output.t,output.GPS.Longitude,new_t);
to_excel(:,4) = interp1(output.t,output.GPS.Altitude,new_t);
to_excel(:,5) = interp1(output.t,output.GPS.GroundSpeed,new_t);
to_excel(:,6) = interp1(output.t,output.pressure,new_t);

xlswrite(fullfile(pathname,[savefile '_proc.xlsx']),output_headers,'Sheet1','A1');
xlswrite(fullfile(pathname,[savefile '_proc.xlsx']),to_excel,'Sheet1','A2');
end

function writecsvdata(output,pathname,savefile)
% Revisit and fix to reduce memory overhead
csv_output = [ ...
    output.t, ...
    output.press_alt,    ...
    output.GPS.Altitude, ...
    output.xaccl,        ...
    output.yaccl,        ...
    output.zaccl         ...
    ];

outputformat = '%f,%f,%f,%f,%f,%f\n';
fid = fopen([pathname filesep savefile '_proc.csv'],'w');
fprintf(fid,outputformat,csv_output.');
fclose(fid);

end

function exportplot(output,pathname,savefile)
temp = strsplit(filepath,filesep);
figname = strjoin(temp(end-3:end),'-');

tempfig = figure('name',figname);
tempplot = subplot(2,2,1);
plot(output.t/1000,output.xaccl)
title('X Accel'); xlabel('Time (s)'); ylabel('Accel (g)');
subplot 222
plot(output.t/1000,output.yaccl)
title('Y Accel'); xlabel('Time (s)'); ylabel('Accel (g)');
subplot 223
plot(output.t/1000,output.zaccl)
title('Z Accel'); xlabel('Time (s)'); ylabel('Accel (g)');
subplot 224
plot(output.t/1000,output.press_alt)
title('Pressure Altitude'); xlabel('Time (s)'); ylabel('Altitude (m)');
savefig(tempfig,[pathname filesep savefile '.fig'])
close(tempfig);
end

function sondedata = pullsonde()
[sonde_filename,sonde_pathname] = uigetfile('*.wprof','Select CAT Generated Wind Profile');

fid = fopen([sonde_pathname sonde_filename],'r');
sondedata = zeros(37,3); % Initialize sonde dataset


saveflag = 0;
lineidx = 1;
while ~feof(fid)
    tline = fgetl(fid);
    if strcmp(tline(1),'*')
        % PI Elevation, start pulling data
        saveflag = 1;
    end
    if saveflag == 1 && strcmp(tline(1:2),'**')
        % Release altitude, save another 3000 ft and break out of loop
        sondedata(lineidx,:) = writewinds(tline(3:end));
        lineidx = lineidx + 1;
        for ii = 1:3
            tline = fgetl(fid);
            sondedata(lineidx,:) = writewinds(tline);
            lineidx = lineidx + 1;
        end
        fseek(fid,0,'eof'); % Move to end of file to break out
        saveflag = 0;
    end
    if saveflag == 1
        sondedata(lineidx,:) = writewinds(tline);
        lineidx = lineidx + 1;
    end
end

    function parsedline = writewinds(dataline)
        % Parse line and export
        temp = regexp(dataline,'(\d*)','tokens');
        parsedline = [str2double(temp{1}{1}), str2double(temp{2}{1}), str2double(temp{3}{1})];
    end

sondedata((sondedata(:,1) == 0),:) = []; % Trim extra entries. Will break if we drop at or below sea level
end