% wamoredecode
% 	 Utility to decode Wamore Log files using Wamore's logdecoder
% 	 executable. If the executable is not present in the folder, an
% 	 attempt will be made to copy it from the top level directory. If
% 	 this fails, the log will be skipped.
% 
%    By default, the program will only decode a single file. If the -R flag
%    is specified the user can select a top level folder and all log files
%    located in the subfolders will be decoded.
%
% created:
%	sjc	2014-06-19
% modified:
%	sjc 2014-06-19


function wamoredecode(varargin)
clc
startdir = cd; % Store current working directory to restore at the end

if ~isempty(varargin) && strcmp(varargin{1},'-R')
    % Recursive search, select top level path then use subdir
    toplevelpath = uigetdir('','Select Top Level Data Folder');
    if ~toplevelpath
        error('No path selected ... exiting')
    end
    
    filelist = subdir(fullfile(toplevelpath,'LOG.*'));
    filelist = cullfiles(filelist);
    for ii = 1:size(filelist,1)
        flag = lookfordecoder(filelist(ii).name,toplevelpath);
        if flag
            decodelog(filelist(ii).name);
        end
    end
else
    if ~isempty(varargin) && ~strcmp(varargin{1},'-R')
        warning('Recursive flag not specified, defaulting to single file processing')
    end
    % Default to single file selection
    [filename,pathname] = uigetfile({'LOG.*','Wamore Raw Log File'},'Select Wamore Binary Log File');
    if ~filename
        error('No file selected ... exiting')
    end
    
    filepath = fullfile(pathname,filename);

    flag = lookfordecoder(filepath,'');
    
    if flag
        decodelog(filepath);
    end
end

cd(startdir)
end

function decodelog(filepath)
[pathname,filename,ext] = fileparts(filepath);
cd(pathname);
filename = [filename,ext];

if ~exist([filepath '.csv'],'file')
    tic
    fprintf('\n... Decoding ...\nLog ID: %s\n   DAQ: %s\n********************\n',filename,pathname)
    dos(['logdecoder.exe ' filename],'-echo');
    toc
    fprintf('\n********************\n')
else
    fprintf('\n... Already Decoded, Skipping Decoder ...\nLog ID: %s\n   DAQ: %s\n********************\n',filename,pathname)
    processlog(filepath);
end
end

function [flag] = lookfordecoder(filepath,decoderpath)
% Check for existence of logdecoder
pathname = fileparts(filepath);
flag = 1;
if ~exist(fullfile(pathname,'logdecoder.exe'),'file')
    try
        copyfile(fullfile(decoderpath,'logdecoder.exe'),pathname);
        fprintf('\nlogdecoder.exe not found, copying from:\n%s\n',decoderpath)
    catch
        warning('logdecoder.exe not found, please provide a source location');
        [~,newdecoderpath] = uigetfile({'*.exe','Windows Executable (*.exe)'},'Select a logdecoder.exe location');
        try
            copyfile(fullfile(newdecoderpath,'logdecoder.exe'),decoderpath);
            copyfile(fullfile(decoderpath,'logdecoder.exe'),pathname);
            fprintf('\nlogdecoder.exe not found, copying from:\n%s\n',newdecoderpath)
        catch
            warning('No valid copy of logdecoder.exe found, skipping:\n%s\n********************\n',filepath)
            flag = 0;
        end
    end
end

end

function filelist = cullfiles(fullfilelist)
% File naming convention and weakness of wildcards with dir leads to some
% false matches. Cleaning these out simplifies processing
cullindex = false(size(fullfilelist,1),1);
filters = {'.csv','.gps','.debug','.mat','.fig','.jpg'};
for ii = 1:size(fullfilelist,1)
    [~,~,ext] = fileparts(fullfilelist(ii).name);
    if sum(strcmp(filters,ext)) ~= 0
        cullindex(ii) = 1;
    end
end
filelist = fullfilelist(cullindex ~= 1);
end

function processlog(filepath)
% Check for existence of processed data file, process if it has not been
[pathname,filename,lognum] = fileparts(filepath);
lognum(lognum=='.') = '';
test = exist([pathname filesep filename lognum '_proc.csv'],'file');

if test == 0
    fprintf('\n... Processing iDAQ Data ...\nLog ID: %s\n   DAQ: %s\n********************\n',[filename '.' lognum],pathname)
    WamoreDataBox_AllData_NoIMU([filepath '.csv'])
else
    fprintf('\n... Already Processed, Skipping Processing ...\nLog ID: %s\n   DAQ: %s\n********************\n',[filename '.' lognum],pathname)
end
end