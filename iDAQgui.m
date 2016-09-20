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
            
            plot(guiObj.mainaxes, xdata, ydata);
        end
        
        
        function windowdata(guiObj)
            guiObj.mainfig.WindowButtonUpFcn = @iDAQgui.stopdrag;
            currxlim = xlim(guiObj.mainaxes);
            axeswidth = currxlim(2) - currxlim(1);
            dragline(1) = line(ones(1, 2)*axeswidth*0.25, ylim(guiObj.mainaxes), ...
                               'Color', 'g', ...
                               'ButtonDownFcn', {@iDAQgui.startdragline, guiObj.mainaxes});
            dragline(2) = line(ones(1, 2)*axeswidth*0.75, ylim(guiObj.mainaxes), ...
                               'Color', 'g', ...
                               'ButtonDownFcn', {@iDAQgui.startdragline, guiObj.mainaxes});
                           
            % TODO: Add listeners for axes pan/zoom
            
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
            % TODO: Check to make sure our indices are valid
            guiObj.iDAQdata.trimdata(dataidx);  % Invoke native data trimming
            
            % Clean up and replot
            delete(dragline);
            guiObj.updateplot()
            guiObj.mainfig.WindowButtonUpFcn = '';
        end
        
        
        function fixedwindowdata(guiObj)
            guiObj.mainfig.WindowButtonUpFcn = @iDAQgui.stopdrag;
            currxlim = xlim(guiObj.mainaxes);
            currylim = ylim(guiObj.mainaxes);
            axeswidth = currxlim(2) - currxlim(1);

            leftx = axeswidth*0.25;
            rightx = axeswidth*0.25 + str2double(guiObj.fixedwindoweb.String)*1000; % Convert edit box to milliseconds
            vertices = [leftx, currylim(1); ...   % Bottom left corner
                        rightx, currylim(1); ...  % Bottom right corner
                        rightx, currylim(2); ...  % Top right corner
                        leftx, currylim(2)];      % Top left corner
            windowpatch = patch('Vertices', vertices, 'Faces', [1 2 3 4], ...
                                'FaceColor', 'green', 'FaceAlpha', 0.3, ...
                                'ButtonDownFcn', {@iDAQgui.startdragwindow, guiObj.mainaxes});
            
            % TODO: Add listeners for axes pan/zoom
            
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
            dataidx(1) = find(xdata >= windowpatch.XData(1), 1);
            dataidx(2) = find(xdata >= windowpatch.XData(2), 1);
            dataidx = sort(dataidx);
            % TODO: Check to make sure our indices are valid
            guiObj.iDAQdata.trimdata(dataidx);  % Invoke native data trimming
            
            % Clean up and replot
            delete(windowpatch);
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
        
        
        function startdragline(lineObj, ~, ax)
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
        
        
        function startdragwindow(patchObj, ed, ax)
            % Helper function for data windowing, sets figure
            % WindowButtonMotionFcn callback to dragline helper
            % while line is being clicked on & dragged
            ax.Parent.WindowButtonMotionFcn = @(s,e)iDAQgui.dragwindow(ax, patchObj);
            patchObj.UserData = ed.IntersectionPoint(1);  % Store initial click location to find a delta later
        end
        
        
        function dragwindow(ax, patchObj)
            % Helper function for data windowing, updates the x coordinate
            % of the dragged line to the current location of the mouse
            % button
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