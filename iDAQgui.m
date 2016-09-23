classdef iDAQgui < handle
    properties
        mainfig         % Main figure window
        mainaxes        % Main axes
        loadbutton      % Data import button
        xdatadropdown   % X data dropdown
        ydatadropdown   % Y data dropdown
        mylineseries    % Our plotted lineseries

        trimpanel       % Panel to organize trimming functionality
        windowtrimbtn   % Arbitrary width window trim button
        fixedwindowbtn  % Fixed width window trim button
        fixedwindowlbl  % Fixed width edit box label
        fixedwindoweb   % Fixed width window length edit box
        donetrimbtn     % Finish data windowing
        savetrimbtn     % Save trimmed data button
        
        iDAQdata        % Imported iDAQ data, iDAQ class
    end
    
    
    methods
        function [guiObj] = iDAQgui()
            % Set up main UI
            guiObj.mainfig = figure('Units', 'Pixels', 'Position', iDAQgui.centeronscreen(1280, 720), ...
                                    'MenuBar', 'none', 'ToolBar', 'figure', 'NumberTitle', 'off');
            guiObj.mainaxes = axes('Parent', guiObj.mainfig, ...
                                   'Units', 'Normalized', 'Position', [0.4 0.1 0.55 0.8]);
            guiObj.loadbutton = uicontrol('Parent', guiObj.mainfig, 'Style', 'pushbutton', ...
                                          'Units', 'Normalized', 'Position', [0.05 0.8 0.25 0.1], ...
                                          'String', 'Load iDAQ Data', 'Callback', @(s,e)guiObj.loaddata());  
            guiObj.xdatadropdown = uicontrol('Parent', guiObj.mainfig, 'Style', 'popupmenu', ...
                                             'Units', 'Normalized', 'Position', [0.05 0.6 0.1 0.1], ...
                                             'String', 'XData Dropdown', 'Callback', @(s,e)guiObj.updateplot()); 
            guiObj.ydatadropdown = uicontrol('Parent', guiObj.mainfig, 'Style', 'popupmenu', ...
                                             'Units', 'Normalized', 'Position', [0.2 0.6 0.1 0.1], ...
                                             'String', 'YData Dropdown', 'Callback', @(s,e)guiObj.updateplot());

            % Set up data trimming UI
            guiObj.trimpanel = uipanel('Parent', guiObj.mainfig, 'Title', 'Data Trimming', ...
                                       'Units', 'Normalized', 'Position', [0.05 0.3 0.25 0.25]);
            guiObj.windowtrimbtn = uicontrol('Parent', guiObj.trimpanel, 'Style', 'pushbutton', ...
                                             'Units', 'Normalized', 'Position', [0.1 0.7 0.6 0.25], ...
                                             'String', 'Window', 'Callback', @(s,e)guiObj.windowdata());
            guiObj.fixedwindowbtn = uicontrol('Parent', guiObj.trimpanel, 'Style', 'pushbutton', ...
                                             'Units', 'Normalized', 'Position', [0.1 0.375 0.6 0.25], ...
                                             'String', 'Fixed Window', 'Callback', @(s,e)guiObj.fixedwindowdata());
            guiObj.fixedwindowlbl = uicontrol('Parent', guiObj.trimpanel, 'Style', 'text', ...
                                              'Units', 'Normalized', 'Position', [0.70 0.6, 0.3 0.1], ...
                                              'String', 'Window Width (s):');
            guiObj.fixedwindoweb = uicontrol('Parent', guiObj.trimpanel, 'Style', 'edit', ...
                                             'Units', 'Normalized', 'Position', [0.725 0.38 0.25 0.22], ...
                                             'String', '12');
            guiObj.savetrimbtn = uicontrol('Parent', guiObj.trimpanel, 'Style', 'pushbutton', ...
                                           'Units', 'Normalized', 'Position', [0.1 0.05 0.6 0.25], ...
                                           'String', 'Save Trimmed Data', 'Callback', @(s,e)guiObj.iDAQdata.save());
            guiObj.donetrimbtn = uicontrol('Parent', guiObj.trimpanel, 'Style', 'pushbutton', ...
                                           'Units', 'Normalized', 'Position', [0.02 0.05 0.96 0.9], ...
                                           'String', 'Done Windowing', 'Visible', 'off', ...
                                           'Callback', @(s,e)uiresume());
            
            % Don't output a class instance if an output agrument isn't specified
            if nargout == 0
                clear guiObj
            end
        end
    end
    
    
    methods (Access = private)
        function loaddata(guiObj)
            % Use the iDAQ class to load in our data and store it to the GUI
            guiObj.iDAQdata = iDAQ;
            guiObj.mainfig.Name = guiObj.iDAQdata.datafilepath;  % Set figure window title to our data filepath
            guiObj.populatexydropdown()  % Populate the XYdata dropdowns
            guiObj.updateplot()  % Make the initial plot
        end
        
        
        function populatexydropdown(guiObj)
            % Pull plottable data fields from the imported iDAQ data
            % Use iDAQ's private 'propstoignore' property to remove fields
            % that are not vectors of data
            propstoignore = iDAQgui.getprivateproperty(guiObj.iDAQdata, 'propstoignore');
            propstoignore = [propstoignore, {'GPS_Valid', 'GPS_Mode', 'GPS_DateTime'}];  % Add a couple more fields to ignore
            datafieldnames = setdiff(fieldnames(guiObj.iDAQdata), propstoignore);  % TODO: fix this flip so XYZ accel/gyro are in the right order
            
            % Update axes data dropdown strings appropriately
            guiObj.xdatadropdown.String = {'time'};  % Force time on x axis for now
            guiObj.ydatadropdown.String = flipud(setdiff(datafieldnames, 'time'));  % Remove time from y axis dropdown
            guiObj.ydatadropdown.Value = 4;  % Set initial plot to time vs. pressure altitude (ft MSL)
        end
        
        
        function updateplot(guiObj)
            % Plot parameters based on dropdown selection
            xdd = guiObj.xdatadropdown;  % Shortcut for brevity
            ydd = guiObj.ydatadropdown;  % Shortcut for brevity
            
            xdata = guiObj.iDAQdata.(xdd.String{xdd.Value});  % Data selected by dropdown
            ydata = guiObj.iDAQdata.(ydd.String{ydd.Value});  % Data selected by dropdown
            
            guiObj.mylineseries = plot(guiObj.mainaxes, xdata, ydata);
        end
        
        
        function windowdata(guiObj)
            guiObj.donetrimbtn.Visible = 'on';
            dataidx = guiObj.iDAQdata.windowdata(guiObj.mylineseries, false);  % Invoke native iDAQ class function
            guiObj.donetrimbtn.Visible = 'off';
            guiObj.iDAQdata.trimdata(dataidx);  % Invoke native iDAQ class function
            
            % Clean up and replot
            guiObj.updateplot()
        end
        
        
        function fixedwindowdata(guiObj)
            guiObj.donetrimbtn.Visible = 'on';
            windowlength = str2double(guiObj.fixedwindoweb.String)*1000;
            dataidx = guiObj.iDAQdata.fixedwindowdata(guiObj.mylineseries, windowlength, false);  % Invoke native iDAQ class function
            guiObj.donetrimbtn.Visible = 'off';
            guiObj.iDAQdata.trimdata(dataidx);  % Invoke native iDAQ class function
            
            % Clean up and replot
            guiObj.updateplot()
        end
    end
    
    
    methods (Static, Access = private)
        function [position] = centeronscreen(l, w)
            screensize = get(0,'ScreenSize');  % Get current screensize
            position = [(screensize(3)-l)/2, (screensize(4)-w)/2, l, w];
        end
        
        
        function [output] = getprivateproperty(obj, fieldname)
            % Get private property, fieldname, of the input class instance,
            % obj. Use the undocumented approach of converting class
            % instance to a structure in order to uncover any properties
            warning off MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
            warning off MATLAB:structOnObject
            tmp = struct(obj);
            warning on MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
            warning on MATLAB:structOnObject
            
            output = tmp.(fieldname);
        end
    end
end