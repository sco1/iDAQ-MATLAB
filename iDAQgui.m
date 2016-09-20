classdef iDAQgui < handle
    properties
        mainfig@matlab.ui.Figure  % Main figure window
        mainaxes@matlab.graphics.axis.Axes  % Main axes
        loadbutton@matlab.ui.control.UIControl  % Data import button
        xdatadropdown@matlab.ui.control.UIControl  % X data dropdown
        ydatadropdown@matlab.ui.control.UIControl  % Y data dropdown

        trimpanel@matlab.ui.container.Panel  % Panel to organize trimming functionality
        windowtrimbtn@matlab.ui.control.UIControl  % Arbitrary width window trim button
        fixedwindowbtn@matlab.ui.control.UIControl  % Fixed width window trim button
        fixedwindowlbl@matlab.ui.control.UIControl  % Fixed width edit box label
        fixedwindoweb@matlab.ui.control.UIControl  % Fixed width window length edit box
        donetrimbtn@matlab.ui.control.UIControl  % Finish data windowing
        savetrimbtn@matlab.ui.control.UIControl  % Save trimmed data button
        
        iDAQdata  % Imported iDAQ data, iDAQ class
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
                                             'String', 'Fixed Window');
            guiObj.fixedwindowlbl = uicontrol('Parent', guiObj.trimpanel, 'Style', 'text', ...
                                              'Units', 'Normalized', 'Position', [0.725 0.6, 0.25 0.1], ...
                                              'String', 'Window Width:');
            guiObj.fixedwindoweb = uicontrol('Parent', guiObj.trimpanel, 'Style', 'edit', ...
                                             'Units', 'Normalized', 'Position', [0.725 0.38 0.25 0.22], ...
                                             'String', '12');
            guiObj.savetrimbtn = uicontrol('Parent', guiObj.trimpanel, 'Style', 'pushbutton', ...
                                           'Units', 'Normalized', 'Position', [0.1 0.05 0.6 0.25], ...
                                           'String', 'Save Trimmed Data');
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
            datafieldnames = flipud(setdiff(fieldnames(guiObj.iDAQdata), propstoignore));  % TODO: fix this flip so XYZ accel/gyro are in the right order
            
            % Update axes data dropdown strings appropriately
            guiObj.xdatadropdown.String = datafieldnames;
            guiObj.ydatadropdown.String = datafieldnames;
            guiObj.ydatadropdown.Value = 5;  % Set initial plot to time vs. pressure altitude (ft MSL)
        end
        
        
        function updateplot(guiObj)
            % Plot parameters based on dropdown selection
            xdd = guiObj.xdatadropdown;  % Shortcut for brevity
            ydd = guiObj.ydatadropdown;  % Shortcut for brevity
            
            xdata = guiObj.iDAQdata.(xdd.String{xdd.Value});  % Data selected by dropdown
            ydata = guiObj.iDAQdata.(ydd.String{ydd.Value});  % Data selected by dropdown
            
            plot(guiObj.mainaxes, xdata, ydata);            
        end
        
        
        function windowdata(guiObj)
            guiObj.mainfig.WindowButtonUpFcn = @iDAQgui.stopdrag;
            currxlim = xlim(guiObj.mainaxes);
            axeswidth = currxlim(2) - currxlim(1);
            dragline(1) = line(ones(1, 2)*axeswidth*0.25, ylim(guiObj.mainaxes), ...
                               'Color', 'g', ...
                               'ButtonDownFcn', {@iDAQgui.startdrag, guiObj.mainaxes});
            dragline(2) = line(ones(1, 2)*axeswidth*0.75, ylim(guiObj.mainaxes), ...
                               'Color', 'g', ...
                               'ButtonDownFcn', {@iDAQgui.startdrag, guiObj.mainaxes});
            
            % Wait until donetrimbtn fires uiresume, then hide it again
            guiObj.donetrimbtn.Visible = 'on';
            uiwait
            guiObj.donetrimbtn.Visible = 'off';
            
            % Use line indices to trim the data
            % Find where the X index of the dragline first matches the
            % plotted data
            % Since find is being used, there can be weird behavior if
            % non-increasing data has been plotted
            xdd = guiObj.xdatadropdown;  % Shortcut for brevity
            xdata = guiObj.iDAQdata.(xdd.String{xdd.Value});  % Data selected by dropdown
            dataidx(1) = find(xdata >= dragline(1).XData(1), 1);
            dataidx(2) = find(xdata >= dragline(2).XData(1), 1);
            dataidx = sort(dataidx);
            guiObj.iDAQdata.trimdata(dataidx);  % Invoke native data trimming
            
            % Clean up and replot
            delete(dragline);
            guiObj.updateplot()
            guiObj.mainfig.WindowButtonUpFcn = '';
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
        
        
        function stopdrag(hObj, ~)
            % Helper function for data windowing, clears figure window
            % WindowButtonMotionFcn callback when mouse button is released
            % after dragging the draggable object
            hObj.WindowButtonMotionFcn = '';
        end
        
        
        function startdrag(lineObj, ~, ax)
            % Helper function for data windowing, sets figure
            % WindowButtonMotionFcn callback to dragline helper
            % while line is being clicked on & dragged
            ax.Parent.WindowButtonMotionFcn = @(s,e)iDAQgui.dragline(ax, lineObj);
        end
        
        
        function dragline(ax, lineObj)
            % Helper function for data windowing, updates the x coordinate
            % of the dragged line to the current location of the mouse
            % button
            currentX = ax.CurrentPoint(1, 1);
            
            % Prevent dragging outside of the current axes limits
            if currentX < ax.XLim(1)
                lineObj.XData = [1, 1]*ax.XLim(1);
            elseif currentX > ax.XLim(2)
                lineObj.XData = [1, 1]*ax.XLim(2);
            else
                lineObj.XData = [1, 1]*currentX;
            end
        end
    end
end