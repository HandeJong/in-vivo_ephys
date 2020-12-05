classdef han_tetrode_viewer <handle
%HAN_TETRODE_VIEWER creates a GUI to visualize a tetrode object
%   This is how I like my clustering software to be

properties
    main_figure;        % Main figure handle
    main_plot;          % Main 3d scatter handle
    setup_figure;       % Setup figure handle
    setup_plot;         % Setup plot handle
    labels;             % Handles to the axis labels
    attribute_list;     % List of all available attributes
    data_shown;         % Struct with currently selected data per axis
    tetrode;            % Handle to the tetrode object
    settings_labels;    % Labels of the settings channel numbers
    drawing;            % Info about whatever the user is drawing
    drawing_h;          % Handle to the user drawing
    settings;           % Struct with settings
    disp_fraction;      % Fraction of waveforms shown
end


methods
    
    function obj = han_tetrode_viewer(tetrode)
        %CONSTRUCTOR

        % Make the main figure
        obj.main_figure = figure('Position',[200, 220, 800, 700],...
            'KeyPressFcn',@obj.key_press,...
            'Color',[0, 0, 0],...
            'Menubar','none',...
            'Toolbar','none',...
            'CloseRequestFcn', @obj.close_request);
        
        % Plot the initial scatter
        prefs = tetrode.settings.preferred_electrodes;
        obj.main_plot = scatter3(tetrode.attributes(prefs(1)).height,...
            tetrode.attributes(prefs(2)).height,...
            tetrode.attributes(prefs(3)).height,...
            'CData' , tetrode.cells,...
            'Marker', '.', 'SizeData',10,...
            'ButtonDownFcn',@obj.mouse_click);
        hold on
        
        % Work on the setting of parent axes (including the callbacks)
        obj.main_plot.Parent.Toolbar.Visible = 'on';
        obj.main_plot.Parent.ButtonDownFcn=@obj.mouse_click;
        obj.main_plot.Parent.Tag = 'main';
        obj.labels={xlabel(['X: Height ' num2str(prefs(1))]),...
            ylabel(['Y: Height ' num2str(prefs(2))]),...
            zlabel(['Z: Height ' num2str(prefs(3))])};
        rotate3d on
        
        % Some formatting of the axes
        axes = gca;
        axes.XColor = [1, 1, 1];
        axes.YColor = [1, 1, 1];
        axes.ZColor = [1, 1, 1];
        
        % Data shown struct
        axes = 'XYZ';
        for i=1:3
            obj.data_shown(i).axis = axes(i);
            obj.data_shown(i).attribute = 'height';
            obj.data_shown(i).channel = prefs(i);
        end
        
        % Plot the user drawing (which is empty for now)
        obj.drawing.data = [];
        obj.drawing.in_use = false;
        obj.drawing_h = plot3(0, 0, 0, 'Visible','off');
        
        % Make the background black
        obj.main_plot.Parent.Color = [0, 0, 0];

        % Store the handle to the tetrode
        obj.tetrode = tetrode;
        
        % Adding the colormap to the main figure
        obj.main_figure.Colormap = han_colormap(obj.tetrode.nr_cells+1);
        
        % Update the Caxis to make sure 0 is included even if there are no
        % unlabeld waveforms.
        temp = caxis(obj.main_plot.Parent);
        caxis(obj.main_plot.Parent, [0, temp(2)]);
        
        % Grab the attribute list
        temp = fieldnames(obj.tetrode.attributes);
        obj.attribute_list = temp(1:7);
        
        % Setup figure
        obj.setup_figure = figure('Position',[1000, 650, 420, 260],...
            'KeyPressFcn',@obj.key_press,...
            'Color',[0, 0, 0],...
            'Toolbar','none',...
            'Menubar','none');
        
        % Display settings
        obj.setup_plot = imagesc(zeros(3,length(obj.attribute_list)),...
            'ButtonDownFcn',@obj.mouse_click,'Tag','settings');
        xticklabels(obj.attribute_list); xtickangle(90);
        yticklabels({'X', 'Y', 'Z'}); yticks([1, 2, 3]);
        caxis([0, 4]);
        title('Parameter Space Mapping')
        
        % Add a grid to the display
        for i=0:4; yline(i+0.5, 'color','r'); end
        for i=0:length(obj.attribute_list)+1
            xline(i+0.5, 'Color', 'r');
        end
        
        % Some more formatting
        axes = gca;
        axes.XColor = [1, 1, 1];
        axes.YColor = [1, 1, 1];
        axes.ZColor = [1, 1, 1];
        
        % Add the numbers indicating the channels
        for i = 1:3
            obj.settings_labels{i} = text(1,i,...
                num2str(obj.data_shown(i).channel),...
                'ButtonDownFcn',@obj.mouse_click,...
                'Tag','settings');
        end
        
        % Update the settings
        obj.update_settings();
        
        % Store the disp fraction
        obj.disp_fraction = 1;
        
    end
    
    function updater(obj, axis)
        % Responsible for updating the presentation (only the channel in i)
        % Channel should be X Y or Z
        
        % Verify chanel
        axis = upper(axis);
        indexer = axis=='XYZ';
        if sum(indexer)~=1
            error('Axis should be X, Y or Z.')
        else
            temp=[1,2,3];
            axis_i = temp(indexer);
        end
        
        % Basic info
        set_channel = obj.data_shown(axis_i).channel;
        set_attribute = obj.data_shown(axis_i).attribute;
        
        % Verify the attribute
        isattribute = false;
        for j=1:length(obj.attribute_list)
            if strcmp(obj.attribute_list{j}, set_attribute)
                isattribute = true;
                break;
            end
        end
        if ~isattribute; error(['Unknown attribute ', isattribute]); end
        
        % Update the relevant axis
        obj.main_plot.([axis, 'Data']) =  getfield(obj.tetrode.attributes(...
                    set_channel),set_attribute);
                
        % Update the label
        obj.labels{axis_i}.String = [axis ': ' set_attribute ' ' ...
            num2str(set_channel)];
        
        % Update the settings
        obj.update_settings();
        
    end
    
    function update_waveforms(obj)
        % Responsible for updating the number, location and color of the
        % waveforms.
        
        
        % Update the location
        % TODO
        
        % Update the color
        obj.main_plot.CData = obj.tetrode.cells;
        
        % Update the color map
        obj.main_figure.Colormap = han_colormap(obj.tetrode.nr_cells+1);
        
        % Update the Caxis to make sure 0 is included even if there are no
        % unlabeld waveforms.
        caxis(obj.main_plot.Parent, [0, obj.tetrode.nr_cells]);
        
    end
    
    function update_settings(obj)
        % Responsible for updating the settings figure
        
        % Is the figure still open? Otherwise just return
        if ~ishandle(obj.setup_figure)
            return
        end
        
        % Check what settings shouls be shown for each axis
        settings = zeros(3, length(obj.attribute_list));
        for i = 1:3
            for j = 1:length(obj.attribute_list)
                if strcmp(obj.data_shown(i).attribute, obj.attribute_list{j})
                    settings(i, j) = obj.data_shown(i).channel;
                    obj.settings_labels{i}.String = obj.data_shown(i).channel;
                    obj.settings_labels{i}.Position(1) = j;
                end
            end
        end
        
        % Update the plot
        obj.setup_plot.CData = settings;
        
    end
    
    function update_drawing(obj, instruction, arg)
        % Updates the user drawing
        
        % Should we update the actual plot
        update = true;
        
        switch instruction
            
            case 'add'
                obj.drawing.data = [obj.drawing.data; arg];
            
            case 'remove'
                obj.drawing.data = obj.drawing.data(1:end-1,:);
                if isempty(obj.drawing.data)
                    for d='XYZ'
                        obj.drawing_h.([d, 'Data']) = [];
                    end
                    update = false;
                end
                
            case 'visible'
                obj.drawing_h.Visible = arg;
                update = false;
            
            case 'delete'
                obj.drawing.data = [];
                update = false;
                for d='XYZ'
                    obj.drawing_h.([d, 'Data']) = [];
                end
                
            otherwise
                error(['Unknown instruction: ' instruction])
        end
 
        
        
        % Update coordinates
        if update
            obj.drawing_h.XData = obj.drawing.data(:,1);
            obj.drawing_h.YData = obj.drawing.data(:,2);
            obj.drawing_h.ZData = obj.drawing.data(:,3);
        end
        
    end
    
    function key_press(obj, ~, ev)
        % KEY_PRESS deals with incomming key pressed on the main figure
        
        % grab the key
        input = lower(ev.Character);
        
        % Figure out the key press
        switch input
            case{'q','w','e','r','a','s','d','f','z','x','c','v'}
                % Change the space
                obj.change_space_key(input);
                
            case 'u'
                % Drawing on
                if obj.drawing.in_use
                    obj.drawing.in_use = false;
                    obj.update_drawing('visible', 'off');
                else
                    obj.drawing.in_use = true;
                    obj.update_drawing('visible', 'on');
                end
            
            case 'i'
                % new drawing
                obj.update_drawing('delete');
                
            case 'o'
                % Cut cluster
                obj.cut_cluster();
                
            case '['
                % Decrease display fraction
                obj.change_disp_fraction(obj.disp_fraction*0.5);
            
            case ']'
                % Increase display fraction
                obj.change_disp_fraction(obj.disp_fraction*2);
                
            case {'1','2','3','4','5','6','7','8','9','10'}
                % Either start the cutter or prune unit in question
                if obj.drawing.in_use && length(obj.drawing.data)>2
                    obj.prune_cluster(str2double(input));
                else
                    cutter_han(obj.tetrode, str2double(input))
                    obj.update_waveforms();
                end
                
            case ' '
                figure(obj.setup_figure)
                figure(obj.main_figure);
                rotate3d
                
                
            otherwise
                disp(['unbound key: ' input])
        end
        
    end
    
    function change_space_key(obj, input)
        % Changes the space on the basis of the key press
        
        % Figure out the axis
        if sum(input=='qwer')==1
            index = input=='qwer';
            axis_i=1;
        elseif sum(input=='asdf')==1
            index = input=='asdf';
            axis_i=2;
        elseif sum(input=='zxcv')==1
            index = input=='zxcv';
            axis_i=3;
        else
            
            disp(['Unbound character: ' input])
            return
        end
        axis = obj.data_shown(axis_i).axis;
        
        % Figure out what we want to change
        temp = [1:4];
        input = temp(index);
        
        % Find the current attribute number
        for i=1:length(obj.attribute_list)
            if strcmp(obj.data_shown(axis_i).attribute, obj.attribute_list{i})
                attribute_i = i;
                break
            end
        end
        
        % Switch all the options (might add more options in the future
        switch input
            
            case 1
                % Channel down
                obj.data_shown(axis_i).channel = max([1, obj.data_shown(axis_i).channel-1]);
                
            case 2
                % Channel up
                obj.data_shown(axis_i).channel = min([4, obj.data_shown(axis_i).channel+1]);
                
            case 3
                % Attribute down
                new_attribute_i = max([1, attribute_i-1]);
                obj.data_shown(axis_i).attribute = obj.attribute_list{new_attribute_i};
                
            case 4
                % Attribute up
                new_attribute_i = min([length(obj.attribute_list), attribute_i+1]);
                obj.data_shown(axis_i).attribute = obj.attribute_list{new_attribute_i};
                
            otherwise
                error(['Input ' num2str(input) ' unknown.'])
        end
        
        % And UPDATE
        obj.updater(axis);
        
    end
   
    function mouse_click(obj, src, ev)
        
        % If the user clicked on the settings, pass X and Y to the settings
        % management function
        if strcmp(src.Tag,'settings')
            obj.manage_setting_click(round(ev.IntersectionPoint(1)),...
                round(ev.IntersectionPoint(2)));
            return
        end

                    
        % Deal with the fact that the user clicked on the main figure
        c_point = ev.IntersectionPoint;
        
        % If we are drawing, add a point
        if obj.drawing.in_use
            obj.update_drawing('add',c_point);
        end
        
        % Mapp all points to a 2d plane based on the camera angle
        
        
        
    end
    
    function manage_setting_click(obj, X, Y)
        % Deals with a click on the settings menu   

        % ERROR HANDELING
        
        % What attribute does the user want?
        new_attribute = obj.attribute_list{X};
        
        % If that attribute is allready selected, rotate the channel
        % instead
        if strcmp(new_attribute, obj.data_shown(Y).attribute)
            obj.data_shown(Y).channel = obj.data_shown(Y).channel+1;
        else
            obj.data_shown(Y).attribute = new_attribute;
        end
            
        % Check if this channel actually exists
        if obj.data_shown(Y).channel>4
            obj.data_shown(Y).channel = 1;
        elseif obj.data_shown(Y).channel<1
            obj.data_shown(Y).channel = 4;
        end
           
        % Update everything only this axis
        obj.updater(obj.data_shown(Y).axis);
        
    end
    
    function [data, drawing] = map_to_2D(obj)
        % Maps the 3D scatter to a 2D plane based on the camera angle
        
        % Make sure the main figure is selected and grab the view angle
        figure(obj.main_figure)
        transformation = view()';
        
        % What do game developers, data scientists, mathematicians, people
        % who like Matlab but NOT people who like Python have in common?
        % ... they all love dot products!
        X = [obj.main_plot.XData', obj.main_plot.YData',...
            obj.main_plot.ZData', ones(length(obj.main_plot.XData),1)];
        data = X*transformation(:,1:2); % only care about new X and new Y
        
        % Same on the drawing
        drawing = [obj.drawing.data, ones(size(obj.drawing.data,1),1)]*transformation;
        
    end
    
    function cut_cluster(obj)
        % Responsible for cutting clusters
        
        % ERROR HANDELING
        
        % Perform the 2D mapping
        [data, polygon] = obj.map_to_2D();
        
        % close the polygon
        polygon = [polygon; polygon(1,:)];
        
        % Find the waveforms inside the polygon
        indexer = inpolygon(data(:,1), data(:,2), polygon(:,1), polygon(:,2));
        
        % Remove waveforms that are allready in a cluster
        indexer(obj.tetrode.cells>0 | isnan(obj.tetrode.cells)) = 0;
        
        % Show the current points as a hypothethical
        [figure_1, figure_2] = obj.tetrode.show_cell(indexer,'hypothetical');

        % Ask if the user wan't to keep this cell
        update = false;
        input = questdlg('Cell or noise?','Cell?','cell','noise','neither','neither');
        switch input
            case 'cell'
                nr_cells = obj.tetrode.nr_cells + 1;
                obj.tetrode.cells(indexer) = nr_cells; 
                obj.tetrode.nr_cells = nr_cells;
                update = true;

            case 'noise'
                obj.tetrode.cells(indexer) = NaN;
                update = true;

            case 'neither'
               disp('Not clustered')

            otherwise
                disp(input)
        end

        % Close the figures
        close(figure_1)
        close(figure_2)
        
        % If update, we should update the waveforms for real and delete the
        % polygon
        if update
            obj.update_waveforms()
            obj.update_drawing('delete');
        end

    end
    
    function prune_cluster(obj, cluster)
        % Cut's off all the waveforms that are outside the cluster
        
        % Error handeling
        if cluster>obj.tetrode.nr_cells
            error(['Cluster ' num2str(cluster) ' does not exist.'])
        end
        
        % Perform the 2D mapping
        [data, polygon] = obj.map_to_2D();
        
        % close the polygon
        polygon = [polygon; polygon(1,:)];
        
        % Find the waveforms inside the polygon
        indexer = inpolygon(data(:,1), data(:,2), polygon(:,1), polygon(:,2));
        
        % Find the waveforms that are part of the cell, but OUTSIDE the
        % polygon
        indexer = obj.tetrode.cells==cluster & ~indexer';
        
        % Did we remove all waveforms, because then we should just remove
        % the cell
        if sum(indexer)==sum(obj.tetrode.cells==cluster)
            obj.tetrode.remove_cell(cluster);
        else
            obj.tetrode.cells(indexer) = 0;
        end
        
        % If update, we should update the waveforms for real and delete the
        % polygon
        obj.update_waveforms()
        obj.update_drawing('delete');


        
    end
    
    function change_disp_fraction(obj, new_fraction)
        % Applies a mask so not all waveforms are shown
        
        % Make sure the fraction does not go above 1
        if new_fraction>1; new_fraction=1; end
        
        % Store the new disp fraction
        obj.disp_fraction = new_fraction;
        
        % Grab the cdata
        cdata = obj.tetrode.cells;
        
        % Make the mask
        mask = rand(size(cdata))>new_fraction;
        
        % Apply the mask
        cdata(mask) = nan;
        
        % Change the CData of the plot
        obj.main_plot.CData = cdata;
    end
    
    function close_request(obj, ~, ~)
        delete(obj.setup_figure);
        obj.main_figure.CloseRequestFcn = [];
        delete(obj.main_figure);
    end
    
end



end

