function cutter_han(tetrode, cell_number, flag)
%CUTTER_HAN Helps with cleaning up clusters by cutting out waveforms
%   Waveforms can be cut out either to 'unclustered' or they can be removed
%   from the dataset as a whole.
%
%   Examples:
%   cutter_han(tetrode, 1); Will help with cleaning up cluster 1, waveforms
%   that are cut out will be flagged as 'unclustered'.
%
%   cutter_han(tetrode, 0); Will help with cleanin up all unclustered
%   waveforms. The waveforms that are cut out will be flaged as noise and
%   removed from the dataset.
%
%   cutter_han(tetrode, 1, 'remove noise'); Will help with cleaning up
%   cluster 1, waveforms taht are cut out will be flagged as noise and
%   removed from the dataset.
%
%   tetrode should be an object of the tetrode class.
%
%   cutter_han is part of Bearphys, Bearphys is made by Han de Jong,
%   j.w.dejong@berkeley.edu.


% Empty variables
start_point = [];
end_point = [];

% Cut to noise or cut to unclustered
cut_to_noise = false; % by default cut to unclustered
if cell_number == 0
    cut_to_noise = true;
end

% Work on a third argument
if nargin==3 && strcmp(flag, 'remove noise')
    cut_to_noise = true;
end

% Find the cell indexer
indexer = tetrode.cells == cell_number;

% Work on the xaxis
interval = 10^6/tetrode.raw_data.hdr.SamplingFrequency; %µs
timeline = [0:interval:1000-interval]';

% 4 subplots for 4 electrodes
disp_fraction = 100;
[main_figure, histogram_figure] = tetrode.show_cell(cell_number, 'fraction', disp_fraction);
close(histogram_figure);

% add callbacks to the figure
main_figure.WindowButtonDownFcn = @mouse_click;
main_figure.WindowButtonMotionFcn = @mouse_motion;
main_figure.WindowKeyPressFcn = @key_press;

% Make the main figure bigger
main_figure.Position = [300, 100, 1000, 800];

% Plot the cutter line
figure(main_figure)
hold on
cutter_line = line([0 0], [0 0], 'Visible','off','Color',[1, 0.6471, 0]);
drawing_line = false;

% Wait for the figure to be closed
% Are we done
we_are_done = false;

% Loop untill we are done
while(~we_are_done)
     % If the figure is closed, end the program
    if ~ishandle(main_figure)
        we_are_done = true;
    end
    
    % quick pause
    pause(0.01);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%% Nested Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function mouse_click(scr, ev)
        % Deals with mouse input
        p_axis = gca;
        c_point = p_axis.CurrentPoint(1,:);
        if drawing_line
            end_point = [c_point(1); c_point(2)];
            cut_waveforms();
        else
            start_point = [c_point(1), c_point(2)];
            drawing_line = true;
        end
        
        update_cutter_line();   
 end

function mouse_motion(scr, ev)
        % Deals with mouse motion
        p_axis = gca;
        c_point = p_axis.CurrentPoint(1,:);
        if drawing_line
            end_point = [c_point(1); c_point(2)];
        end
        
        update_cutter_line();      
end

function key_press(scr, ev)
        % Deals with key presses
        
        switch ev.Key
                
            case 'space' % delete line (do not cut)
                drawing_line = false;
                start_point =[];
                end_point = [];
                update_cutter_line();
                
            case 'a' % show a higher fraction of waveforms
                disp_fraction = disp_fraction * 2;
                if disp_fraction>100; disp_fraction = 100; end
                disp(['Showing ' num2str(disp_fraction) '% of waveforms.'])
                replace_figure();
            
            case 'z' % show a smaller fraction of waveforms
                disp_fraction = disp_fraction * 0.5;
                disp(['Showing ' num2str(disp_fraction) '% of waveforms.'])
                replace_figure();
                
            otherwise
                disp('Key not recognized.')
        end
 end

function update_cutter_line()
    
    % Move the cutter line to the plot the user has last clicked on
    cutter_line.Parent = gca;
    
    % Draw the line
    if drawing_line && ~isempty(end_point)
        cutter_line.XData = [start_point(1), end_point(1)];
        cutter_line.YData = [start_point(2), end_point(2)];
        cutter_line.Visible='on';
    else
        cutter_line.Visible='off';
        return
    end
    
    % Figure out if this is a vertical line.
    if abs(start_point(1) - end_point(1))<25
        cutter_line.UserData = 'vertical';
        cutter_line.Color = [1, 0.6471, 0];
    else
        cutter_line.UserData = 'not vertical';
        cutter_line.Color = [0, 0.3529, 1];
    end

end

function cut_waveforms()
    
    % Stop drawing the line
    drawing_line = false;
    
    % find out which axis we are working on
    hax = gca;
    electrode_nr = str2num(hax.Title.String(end));
    
    % First find the indexer of the waveforms that should be cut
    data_Y = squeeze(tetrode.data(electrode_nr,:,:));
    data_X = repmat([1:size(data_Y,1)]',1, size(data_Y,2));
    
    % For the line, we have to calculate back to X_index and raw bitvalue,
    % because the data is stored in that way in the object
    [~, X_index(1)] = min(abs(timeline-start_point(1)));
    [~, X_index(2)] = min(abs(timeline-end_point(1)));
    Y_index(1) = start_point(2)/(tetrode.settings.ADBitVolts(electrode_nr)*10^6);
    Y_index(2) = end_point(2)/(tetrode.settings.ADBitVolts(electrode_nr)*10^6);
    
    % If the line is not vertical, we'll use polyxpoly to find
    % intersections. This is a bit slow.
    if strcmp(cutter_line.UserData, 'not vertical')
        % Use polyxpoly to find intersection
        [~, ~, c] = polyxpoly(data_X, data_Y, X_index, Y_index);

        % Now from the linesegment index in c to the waveform index
        new_indexer = c(:,1)/(size(data_Y,1));

        % Note that polyxpoly linearized the data and ALSO COUNTS THE LAST
        % VALUE OF EVERY COLUMN TO THE FIRST VALUE OF THE NEXT COLUM AS A LINE
        % SEGMENT. (It took me a full day to figure this out). This is why we
        % divide by size(data_Y,1) and not size(data_Y,1)-1.

        % If the linesegment divided by the number of datapoints per colum is a
        % round number, polyxpoly cut the non-existing segment (the last
        % segments of each column that supposedly connects to the next column).
        new_indexer = unique(ceil(new_indexer(mod(new_indexer,1)>0)));

        % Convert the indexer to a logical
        logical_indexer = false(1,size(data_Y,2));
        logical_indexer(new_indexer) = true;
        
    else
        % Much more easy, we just have to look at one X coordinate
        X_index = round(mean(X_index));
        
        logical_indexer = data_Y(X_index,:)>min(Y_index) & data_Y(X_index,:)<max(Y_index);
        
    end
    
    % Make sure we do this only on the selected cell
    logical_indexer = logical_indexer & indexer;

    % Remove these waveforms or label them unclustered
    if cut_to_noise
        tetrode.remove_noise('indexer', logical_indexer);
    else
        tetrode.cells(logical_indexer) = 0;
    end
    
    % Print some text
    disp(['Removed ' num2str(sum(logical_indexer)) ' waveforms.']);
    
    % Grab the indexer again
    indexer = tetrode.cells == cell_number;
    
    % Empty the cutting line for good measure
    start_point =[];
    end_point = [];
    
    % And replace the figure
    replace_figure();
    
end

function replace_figure()
    
    % Now make a new main figure
    position = main_figure.Position;
    close(main_figure)
    
    % Make a new one:
    % 4 subplots for 4 electrodes
    [main_figure, histogram_figure] = tetrode.show_cell(cell_number,'fraction', disp_fraction);
    close(histogram_figure);

    % add callbacks to the figure
    main_figure.WindowButtonDownFcn = @mouse_click;
    main_figure.WindowButtonMotionFcn = @mouse_motion;
    main_figure.WindowKeyPressFcn = @key_press;

    % Restore the original position
    main_figure.Position = position;

    % Plot the cutter line
    figure(main_figure)
    hold on
    cutter_line = line([0 0], [0 0], 'Visible','off','Color',[1, 0.6471, 0]);
    drawing_line = false;
    
end


end