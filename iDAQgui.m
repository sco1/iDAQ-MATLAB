classdef iDAQgui < handle
    properties
        mainfig@matlab.ui.Figure
        mainaxes@matlab.graphics.axis.Axes
        loadbutton@matlab.ui.control.UIControl
        xdatadropdown@matlab.ui.control.UIControl
        ydatadropdown@matlab.ui.control.UIControl
        iDAQdata
    end
    
    methods
        function [guiObj] = iDAQgui()
            guiObj.mainfig = figure('Units', 'Pixels', 'Position', iDAQgui.centeronscreen(1280, 720), ...
                                    'MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off');
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
            
            if nargout == 0
                clear guiObj
            end
        end
    end
    
    methods (Access = private)
        function loaddata(guiObj)
            guiObj.iDAQdata = iDAQ;
            guiObj.mainfig.Name = guiObj.iDAQdata.datafilepath;
            guiObj.populatexydropdown()
            guiObj.updateplot()
        end
        
        function populatexydropdown(guiObj)
            % Pull plottable data fields from the imported iDAQ data
            % Use iDAQ's private 'propstoignore' property to remove fields
            % that are not vectors of data
            propstoignore = iDAQgui.getprivateproperty(guiObj.iDAQdata, 'propstoignore');
            propstoignore = [propstoignore, {'GPS_Valid', 'GPS_Mode', 'GPS_DateTime'}];  % Add a couple more fields to ignore
            datafieldnames = flipud(setdiff(fieldnames(guiObj.iDAQdata), propstoignore));
            
            % Update axes data dropdown strings appropriately
            guiObj.xdatadropdown.String = datafieldnames;
            guiObj.ydatadropdown.String = datafieldnames;
            guiObj.ydatadropdown.Value = 5;  % Set initial plot to time vs. pressure altitude (ft MSL)
        end
        
        function updateplot(guiObj)
            % Plot parameters based on dropdown selection
            xdd = guiObj.xdatadropdown;  % Shortcut for brevity
            ydd = guiObj.ydatadropdown;  % Shortcut for brevity
            
            xdata = guiObj.iDAQdata.(xdd.String{xdd.Value});
            ydata = guiObj.iDAQdata.(ydd.String{ydd.Value});
            
            plot(guiObj.mainaxes, xdata, ydata);            
        end
    end
    
    methods (Static, Access = private)
        function [position] = centeronscreen(l, w)
            screensize = get(0,'ScreenSize');  % Get current screensize
            position = [(screensize(3)-l)/2, (screensize(4)-w)/2, l, w];
        end
        
        function [output] = getprivateproperty(obj, fieldname)
            % Get private property, fieldname, of the input class instance, obj  
            warning off MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
            warning off MATLAB:structOnObject
            tmp = struct(obj);
            warning on MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
            warning on MATLAB:structOnObject
            
            output = tmp.(fieldname);
        end
    end
end