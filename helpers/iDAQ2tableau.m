function iDAQ2tableau(pathname)
% Batch process a directory of 'zoomed' SLAAD iDAQ data
if nargin == 0
%     pathname = uigetdir('', 'Select Processed SLAAD Data Directory');
    pathname = 'C:\Project Data\General MATLAB\Wamore-IMU\test data';
end

if ~ischar(pathname) || exist(pathname, 'dir') ~= 7
    error('Invalid path specified');
end

warning('off', 'MATLAB:table:ModifiedVarnames');
dropdatalookup = parselookup(fullfile(pathname, 'Drop Data Sheet.xlsx'));

xlsxfiles = dir(fullfile(pathname, '*_zoom.xlsx'));
if ~isempty(xlsxfiles)
    % Open ActiveX server
    Excel = actxserver('Excel.Application');
    
    % Check to see if the tableau mega sheet already exists in the
    % directory
    tableaufilepath = fullfile(pathname, 'Tableau Mega Sheet.xlsx');
    if ~exist(tableaufilepath, 'file')
        % File doesn't exist, create it
        ExcelWorkbook = Excel.workbooks.Add;
        
        % Write our headers and save
        WorkSheets = Excel.sheets;
        TargetSheet = get(WorkSheets,'item', 1);  % Find and Activate Sheet1
        TargetSheet.Activate();
        header = {'Method', 'Drop Number', 'Aircraft', 'Weight', ...
                  'Time (s)','X Gyro (deg/s)', 'Y Gyro (deg/s)', 'Z Gyro (deg/s)', ...
                  'X Acceleration (G)', 'Y Acceleration (G)', 'Z Acceleration (G)'};
        nheaders = size(header, 2);
        rcolumn = excelcol(nheaders);
        range = sprintf('A1:%s1', rcolumn);
        Excel.Range(range).Select;
        set(Excel.selection, 'Value', header);
        ExcelWorkbook.SaveAs(tableaufilepath, 51);
    else
        ExcelWorkbook = Excel.workbooks.Open(tableaufilepath);
        WorkSheets = Excel.sheets;
        TargetSheet = get(WorkSheets,'item', 1);  % Find and Activate Sheet1
        TargetSheet.Activate();
    end
    
    for ii = 1:numel(xlsxfiles)
        % Get drop ID from file name, assumes file is named the same as the
        % YPG drop ID
        datafilepath = fullfile(pathname, xlsxfiles(ii).name);
        [~, dropID] = fileparts(datafilepath);
        dropID = str2double(regexp(dropID, '\d+', 'match'));
        
        tmp = readtable(datafilepath);
        dropinfo = repmat(dropdatalookup(dropID), height(tmp), 1);
        datatowrite = [dropinfo, num2cell(tmp{:,[1,3:8]})];
        xlsxappend(Excel, ExcelWorkbook, datatowrite);
    end
end
ExcelWorkbook.Close(false);
Excel.Quit;
Excel.delete;
warning('on', 'MATLAB:table:ModifiedVarnames');
end


function [dropdatalookup] = parselookup(filepath)

if ~exist(filepath, 'file')    
    [filename, pathname] = uigetfile('*.xlsx', 'Select YPG Drop Data Lookup Sheet');
    filepath = fullfile(pathname, filename);
end
tmp = readtable(filepath);

% Use a map container rather than a table to avoid having to use strings to
% reference drop numbers
dropdatalookup = containers.Map('KeyType', 'uint32', 'ValueType', 'any');
for ii = 1:height(tmp)
    % Key: DropID Value: {Malfunction String, Drop Number, Aircraft, TRW}
    dropdatalookup(tmp{:,2}(ii)) = [tmp{:,6}(ii), tmp{:,2}(ii) tmp{:,7}(ii), num2cell(tmp{:,5}(ii))];
end
end


function xlsxappend(Excel, ExcelWorkbook, data)
usedrange = get(Excel.Activesheet, 'UsedRange');  % Find extent of used data
rowextent = size(usedrange.value, 1);
[ndatarows, ndatacols] = size(data);
rcolumn = excelcol(ndatacols);
range = sprintf('A%u:%s%u', rowextent+1, rcolumn, rowextent+ndatarows);
Excel.Range(range).Select;
set(Excel.selection, 'Value', data);
ExcelWorkbook.Save
end


function col = excelcol(n)
rcolletter = mod(n-1,26)+1;  % Rightmost column letter
npastz = fix((n-1)/26);  % See if we've gone past the Zs (Z, ZZ)

% Recurse if needed
if npastz >= 1
    col = [excelcol(npastz) char(rcolletter+64)] ;
else
    col = char(rcolletter+64);
end
end