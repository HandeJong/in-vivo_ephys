classdef tetrode<handle
    %TETRODE Imports Neuralynx .NTT files and helps with clustering
    %   Current methods include:
    %
    %       - remove_noise('noise type') e.g. obj.remove_noise('clipping');
    %       will remove all waveforms that clip the maximum value from the
    %       dataset. obj.remove_noise('max height', 100); will remove all
    %       waveforms with a height of >100µV.
    %
    %       - present_figure('atribute') e.g. obj.present_figure('height')
    %       will plot the height of all waveforms as a scatter plot on 3
    %       electrodes. You can also provide the electrodes you want to see
    %       like this: obj.present_figure('height',[1 2 4]); (For electrode
    %       1, 2 and 4.
    %       
    %       - show_cell(cell_number) e.g. obj.show_cell(1) will plot the
    %       waveforms on all 4 electrodes on cell 1 and obj.show_cell(nan)
    %       will simply plot all waveforms.
    %
    %       - set_offline_threshold(threshold (1x4)) e.g.
    %       obj.set_offline_threshold([65 65 65 65]); Will set a post-hoc
    %       threshold and delete all waveforms that do not meet this
    %       threshold on any electrode.
    %
    %       - full_pca() e.g. obj.full_pca() will plot a 3D plot
    %       with the first 3 principle components of the entire dataset.
    %       The 3 axis represent the 3pc's, NOT 3 electrodes.
    %
    %       - peri_event() e.g. obj.peri_event(stamps); will plot a
    %       peri-event histogram of all units (and unclustered datapoints)
    %       around the timepoints in the array stamps. Note that stamps
    %       should be in µs. You can also a window (in µs) as a 3rd
    %       argument.
    %
    %       - set_interval() e.g. obj.set_interval([0 20]); from now on the
    %       attributes (e.g. 'height', 'pca_1', etc..) are calulated using
    %       the first 20 datapoints of each waveform.
    %
    %       - save_data('filename') e.g. obj.save_data('filename') will
    %       save the tetrode object to the current folder.
    %
    %   Tetrode uses part of Fieldtrip, (Copyright (C) 2005), Robert
    %   Oostenveld. For more information about Fieldtrip (including license
    %   information (GNU) see: http://www.fieldtriptoolbox.org.
    %
    %   Tetrode is part of Bearphys, Bearphys is made by Johannes de Jong,
    %   j.w.dejong@berkeley.edu
    
    
    properties
        % In principle all data properties are organized as follows:
        % (channels x data points x n)
        raw_data        % Stores imported tetrode (struct)
        data            % Data after manipulations (c,d,n)
        attributes      % Attributes of the sweeps in data (e.g. 'height')
        timestamps      % Timestamps of the waveforms in data (n)
        cells           % Clustered units(n);
        nr_cells        % The total number of clustered units
        handles         % Handles to figures and plots
        settings        % Struct with settings.
        notes           % Notes for 
    end
    
    % Standard methods
    methods
        function obj = tetrode(filename)
            %TETRODE Construct an instance of this class
            %   Uses Fieldtrip m files to import a tetrode file
            
            obj.raw_data = read_neuralynx_ntt(filename, 1, inf);
            
            % MOVE ALL THIS TO SEPARATE FUNCTION!
            
            % Grab the data
            obj.data = obj.raw_data.dat;
            
            % Grab any pre-clustered cells
            obj.cells = obj.raw_data.CellNumber;
            
            % Find the total number of clusters
            obj.nr_cells = max(obj.cells);
            
            % Fill out the timestamps
            obj.timestamps = obj.raw_data.TimeStamp;
            
            % Find the recording interval
            obj.settings.recording_interval =...
                [obj.raw_data.hdr.FirstTimeStamp, obj.raw_data.hdr.LastTimeStamp];
            
            % Fill out the settings
            obj.settings.interval = [1, 32];
            obj.settings.preferred_electrodes = [1 2 3]; % Because humans like three dimensions
            obj.settings.colorlist = ['kgrbmcgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbm'];
            obj.settings.remove_check = true; % Prevents removal of sweeps without user confirmation
            
            % Find the DBitVolts (from the header char...)
            header = obj.raw_data.hdr.Header;
            for i = 1:5000
                if strcmp('ADBitVolts', header(i:i+9))
                    break;
                end
            end
            obj.settings.ADBitVolts(1) = str2num(header(i+11:i+36));
            obj.settings.ADBitVolts(2) = str2num(header(i+38:i+63));
            obj.settings.ADBitVolts(3) = str2num(header(i+65:i+90));
            obj.settings.ADBitVolts(4) = str2num(header(i+92:i+117));
            
            % Grab the recording date
            for i = 1:5000
                if strcmp('(m/d/y)', header(i:i+6))
                    break;
                end
            end
            obj.raw_data.date = header(i+9:i+18);
            
            % Grab the recording time
            for i = 1:5000
                if strcmp('(h:m:s.ms)', header(i:i+9))
                    break;
                end
            end
            obj.raw_data.time = header(i+11:i+22);
            
            % Figure out which electrodes are not recording anything at all
            % and label them 'false' in the working electrodes property
            for i=1:4
                if sum(sum(obj.data(i,:,:)))==0
                    obj.settings.working_electrodes(i) = false;
                else
                    obj.settings.working_electrodes(i) = true;
                end
            end
            
            % Find the Inputrange(from the header char...)
            for i = 1:5000
                if strcmp('InputRange', header(i:i+9)); break; end
            end
            new_char = header(i+11:i+30);
            for i=1:length(header)
                if strcmp(new_char(i),'-'); break; end
            end
            obj.settings.InputRange = str2num(new_char(1:i-1));
            
            % Find the Threshold Value(from the header char...)
            for i = 1:5000
                if strcmp('ThreshVal', header(i:i+8)); break; end
            end
            new_char = header(i+10:i+30);
            for i=1:length(header)
                if strcmp(new_char(i),'-'); break; end
            end
            obj.settings.ThresVal = str2num(new_char(1:i-1));
           
            % Fill out the attributes
            obj.find_attributes;
            
            % Set the cutoff for display performance issues
            obj.settings.disp_cutoff = 40000;
            
            % Figure out the prefered electrodes (which the most variation in height)
            for i=1:4
                devs(i) = std(obj.attributes(i).height);
            end
            [~, show_electrodes] = sort(devs, 'descend');
            show_electrodes = sort(show_electrodes(1:3));
            obj.settings.preferred_electrodes = show_electrodes;
            
            % That's it
        end
        
        function find_attributes(obj)
            % Find attributes updates all the sweep attributes
            
            % Analyse the following interval
            start = obj.settings.interval(1);
            stop = obj.settings.interval(2);
            
            % Grab the data from the 4 electrodes
            for i=1:4
                temp_data = squeeze(obj.data(i,start:stop,:)).*obj.settings.ADBitVolts(i)*10^6;
                
                % grab the peak
                obj.attributes(i).peak = max(temp_data);
                
                % grab the valley
                obj.attributes(i).valley = min(temp_data);
                
                % grab the height
                obj.attributes(i).height = obj.attributes(i).peak - obj.attributes(i).valley;
                
                % grab the energy
                % See Schmitzer-Torber et al. Neuroscience 2005
                obj.attributes(i).energy = sum(temp_data.^2)./(stop-start + 1);
                
                % run PCA, but only on 'working electrodes'
                if obj.settings.working_electrodes(i)
                    [~ ,score,~ ,~ ,~ ] = pca(squeeze(temp_data)');
                    obj.attributes(i).pca_1 = score(:,1)';
                    obj.attributes(i).pca_2 = score(:,2)';
                    obj.attributes(i).pca_3 = score(:,3)';
                else
                    obj.attributes(i).pca_1 = zeros(1,size(temp_data,2));
                    obj.attributes(i).pca_2 = zeros(1,size(temp_data,2));
                    obj.attributes(i).pca_3 = zeros(1,size(temp_data,2));
                end
                
                % run PCA on normalized energy waveforms (working
                % channels)
                if obj.settings.working_electrodes(i)
                    temp_data = temp_data./sqrt(obj.attributes(i).energy);
                    [~ ,score,~ ,~ ,~ ] = pca(squeeze(temp_data)');
                    obj.attributes(i).norm_pca_1 = score(:,1)';
                    obj.attributes(i).norm_pca_2 = score(:,2)';
                    obj.attributes(i).norm_pca_3 = score(:,3)';
                else
                    obj.attributes(i).norm_pca_1 = zeros(1,size(temp_data,2));
                    obj.attributes(i).norm_pca_2 = zeros(1,size(temp_data,2));
                    obj.attributes(i).norm_pca_3 = zeros(1,size(temp_data,2));
                end
                
            end
            
        end
        
        function [removed, removed_indexer] = remove_noise(obj, varargin)
            %REMOVE_NOISE Removes noise on the basis of the arguments given
            %in varargin
            %
            %   Examples:
            %   >>remove_noise('max heigh', 100); Will remove all waveforms
            %   of which the height is bigger then 100µV on ANY electrode.
            %
            %   >>remove_noise('min height', 50); Will remove all waveforms
            %   of which the height is smaller then 100µV on EVERY
            %   electrode.
            %
            %   >>remove_noise('indexer',[true false false true]); will
            %   remove the 2th and 3rd waveform from the dataset. (In
            %   reality the logical will be much longer of course).
            
            % The output is boolean on wether or not any waveforms were
            % actually removed
            removed = false;
            removed_indexer = [];
            no_show = false; % Ask the user before deleting ans waveforms
            
            % Deal with input arguments
            for i=1:length(varargin)
                
                
                switch varargin{i}
                    
                    % max height
                    case 'max height'
                            indexer = obj.attributes(1).height> varargin{i+1}...
                                | obj.attributes(2).height > varargin{i+1}...
                                | obj.attributes(3).height > varargin{i+1}...
                                | obj.attributes(4).height > varargin{i+1};
                            break;
                            
                    % max height
                    case 'min height'
                            indexer = obj.attributes(1).height< varargin{i+1}...
                                & obj.attributes(2).height < varargin{i+1}...
                                & obj.attributes(3).height < varargin{i+1}...
                                & obj.attributes(4).height < varargin{i+1};
                            break;
                    
                    % Remove isolated cluster        
                    case 'remove cluster'
                        indexer = obj.cells == varargin{i+1};
                        indexer2 = obj.cells>varargin{i+1};
                        obj.cells(indexer2) = obj.cells(indexer2)-1;
                        varargin{i+1} = 'skipp';
                        warning('Not a finished method, clicking no in the dialog will result in errors')
                    
                    % Remove all waveforms that clip the max value    
                    case 'clipping'
                        clip_value = obj.raw_data.hdr.ADMaxValue;
                        indexer = obj.data==clip_value | obj.data==-1*clip_value;
                        indexer = logical(squeeze(sum(sum(indexer))));
                    
                    % Remove all waveforms indexed in the following logical    
                    case 'indexer'
                        indexer = varargin{i+1};
                        varargin{i+1} = 'skipp';
                    
                    % Do not bother showing the findings just delete
                    case 'no show'
                        disp('hoi')
                        no_show = true;
                    
                    % Skipp this input argument    
                    case 'skipp'
                        X = 5; % Do nothing.
                        
                    otherwise
                        error('Unknown argument type, juse the help method to display example option.')
                end

            end
            
            % Is the remove check off?
            if ~ obj.settings.remove_check
                no_show = true;
            end
            
            % Check if the indexer even picked up on any waveforms
            if sum(indexer)==0
                disp('No waveforms met exclusion criteria.')
                return
            end
            
            if ~no_show
                % Show the removed noise
                [figure_1, figure_2] = obj.show_cell(indexer,'hypothetical');

                % Ask the user if they want to indeed remove these
                % waveforms?
                w_percentage = 100*sum(indexer)/length(obj.timestamps);
                input = questdlg(['Remove these ' num2str(sum(indexer)) '(' num2str(w_percentage) '% of total) waveforms?'],'Remove?','yes','no','no');
                if strcmp(input,'yes')

                    % Mark these sweeps nan
                    obj.cells(indexer) = nan;

                    % Change the bool
                    removed = true;
                end

                % Close the figures
                close(figure_1)
                close(figure_2)
            else
                 % Mark these sweeps nan
                obj.cells(indexer) = nan;

                % Change the bool
                removed = true;
            end
            
            % Give the output arguments
            removed_indexer = indexer;
            
            % Make sure the object stays consistent
            obj.check_object();
            
        end
        
        function [waveform_figure, scatter_figure] = present_figure(obj, varargin)
            %PRESENT_FIGURE presents a 3D scatterplot with the requested
            %atribute on 3 electrodes on 3 axis.
            % 
            %Examples:
            %
            %obj.present_figure('height') will plot the height on the first
            %3 electores.
            %
            %obj.present_figure('height', [1 3 4]) will plot the height on
            %electrode 1, 3 and 4.
            
            % By default showing all sweeps?
            plot_average = false;
            
            % Set the Y axis to the inputrange
            y_axis_is_input_range = false;
            
            % Make a list of all attributes
            attribute_list = fieldnames(obj.attributes);
            
            % Colorlist for the markers
            colorlist = obj.settings.colorlist;
            
            % Default channels to be displayed
            channel = obj.settings.preferred_electrodes;
            
            % By default, don't snow NaN sweeps
            plot_nan = false;
            
            % By default plot height
            attribute = 'height';
            
            % Deal with input arguments
            for i=1:length(varargin)
                
                if isnumeric(varargin{i}) && length(varargin{i})==3
                    channel = varargin{i};
                else
                    % Check if the argument is an attributed
                    isattribute = false;
                    for j=1:length(attribute_list)
                        if strcmp(attribute_list{j}, varargin{i})
                            isattribute = true;
                            attribute = varargin{i};
                            break;
                        end
                    end
                    
                    % If not an attribute, maybe it's something else
                    if ~isattribute
                        
                        switch varargin{i}
                            
                            case 'show removed'
                                % Show NaN sweeps as well
                                plot_nan = true;
                                
                            case 'average'
                                % Plot average waveform instead of all
                                % waveforms
                                plot_average = true;
                            
                            otherwise
                                % We really not know, let the user know
                                disp(' ')
                                disp(['Argument ''' varargin{i} ''' not recognized.'])
                                disp('Currently only the following attributes are supported:')
                                for i=1:length(attribute_list)
                                    disp(['    - ' attribute_list{i}])
                                end
                                disp(' ')
                                disp('In addition present_figure supports the following arguments:')
                                disp('    - show removed')
                                disp('    - average')
                                disp('    - A 3D vector containing the 3 electrodes that should be shown.')
                                return
                                
                        end
                    end 
                end
            end
                
            % Grab the data
            for i=1:4
                XYZ(i,:) = getfield(obj.attributes(i),attribute);
            end
            
            % Make indexers for every cells
            for i=0:obj.nr_cells
                indexer{i+1} = obj.cells==i;
            end

            % If there are to many waveforms we will plot only 1% of them
            % to maintain performance
            cutoff = obj.settings.disp_cutoff;
            for i=1:length(indexer)
                if sum(indexer{i})>cutoff
                    new_indexer = zeros(size(indexer{i}));
                    new_indexer(1:20:end)=indexer{i}(1:20:end);
                    indexer{i} = logical(new_indexer);
                    
                    % Plot the waveforms
                    if i==1
                        disp(['Unclustered: Showing only 5% (n = ' num2str(sum(indexer{i}==1)) ') of waveforms/datapoints.'])
                    else
                        disp(['Cell ' num2str(i-1) ': Showing only 5% (n = ' num2str(sum(indexer{i}==1)) ') of waveforms/datapoins.'])
                    end
                end
            end
            
            % Make the figure, plot unclustered datapoints
            scatter_figure = figure;
            scatter_figure.Position = [432, 300, 560, 420];
            
            % Plot identified clusters
            for i=0:obj.nr_cells
                
                % figure out the name of this dataset
                if i==0
                    dataname{i+1} = 'Unclustered';
                else
                    dataname{i+1} = ['Cell ' num2str(i)];
                end
                scatter3(XYZ(channel(1),indexer{i+1}), XYZ(channel(2),indexer{i+1}), XYZ(channel(3),indexer{i+1}),...
                    'DisplayName', dataname{i+1},...
                    'MarkerEdgeColor',colorlist(i+1));
                hold on
            end
            
            % If requested by the user, plot NaN sweeps as well
            if plot_nan
                scatter3(XYZ(channel(1),isnan(obj.cells)), XYZ(channel(2),isnan(obj.cells)), XYZ(channel(3),isnan(obj.cells)),...
                    'DisplayName', 'removed waveforms',...
                    'MarkerEdgeColor',colorlist(1)) 
            end
           
            % Label figure and axis
            title(attribute)
            xlabel(['Electrode ' num2str(channel(1))])
            ylabel(['Electrode ' num2str(channel(2))])
            zlabel(['Electrode ' num2str(channel(3))])
            
            % ***** Plot the waveforms *****
            
            % Make a figure
            waveform_figure = figure('Name','Waveforms');
            waveform_figure.Position = [993 300, 560, 420];
            
            % Work on the xaxis
            interval = 10^6/obj.raw_data.hdr.SamplingFrequency; %µs
            timeline = [0:interval:1000-interval]';
            
            % 4 subplots for 4 electrodes
            for i=1:4
                subplot(2,2,i)
                
                % Plot all cells and unclustered
                for j=0:obj.nr_cells
                    % Plot ydata in µv
                    ydata = squeeze(obj.data(i,:,indexer{j+1}).*obj.settings.ADBitVolts(i))*10^6;
                    
                    % In the special case that there is only one waveform, make
                    % sure that Y is still oriented in the right way
                    if sum(indexer{j+1})==1
                        ydata = ydata';
                    end
                    
                    if plot_average
                        stdev_y = std(ydata');
                        ydata = mean(ydata,2);

                        % Plot the stdev shadow
                        fill([timeline', flipud(timeline)'], [ydata'-stdev_y, fliplr(ydata'+stdev_y)],[1 0 0],...
                            'FaceColor',colorlist(j+1),...
                            'linestyle','none',...
                            'FaceAlpha',0.1)
                        hold on
                    end
                    
                    % Grab the Xdata in µs
                    xdata = repmat(timeline,1, size(ydata,2),1);
                    
                    % Convert the data for faster performance
                    xdata = [xdata; nan(1,size(xdata,2))];
                    xdata = xdata(:);
                    ydata = [ydata; nan(1,size(ydata,2))];
                    ydata = ydata(:);
                    
                    % Plot the data
                    plot(xdata, ydata, 'Color',colorlist(j+1),...
                        'DisplayName',dataname{j+1});
                    hold on
                end
                
                % Labels and titles
                ylabel('Voltage (µv)')
                xlabel('Time (µs)')
                title(['Electrode ' num2str(i)]);
                
                % Set the y_axis to the input range if that is requested
                if y_axis_is_input_range
                    ylim([-obj.settings.InputRange(i) obj.settings.InputRange(i)])
                end
                
                % Plot the threshold line
                hold on
                line(get(gca,'XLim'), [obj.settings.ThresVal(i), obj.settings.ThresVal(i)],...
                    'Color',[0.2 0.2 0.2],...
                    'LineStyle','--',...
                    'DisplayName','Threshold');
            end
            
        end
        
        function [waveform_figure, histogram_figure] = show_cell(obj, cell_number, varargin)
            %SHOW_CELL Presents the waveform of one cell on 4 electrodes
            
            % Work on the flag
            plot_average = false;
            hypothetical_cell = false;
            disp_fraction = 1;
            for i = 1:length(varargin)
                switch varargin{i}
                    
                    % Skip this argument
                    case 'skipp'
                        hoihoi = 5;
                        
                    % We will plot the average and stdev instead of all
                    % waveforms   
                    case 'average' 
                        plot_average = true;
                    
                    % Plot a hypothetical cell, not an identified cluster
                    case 'hypothetical'
                        hypothetical_cell = true;
                        
                    % Plot only a fraction of the waveforms    
                    case 'fraction'
                        disp_fraction = round(100/varargin{i+1});
                        varargin{i+1} = 'skipp';
                        
                    otherwise
                        error('Unknown Argument')
                end
            end
            
            % Real unit or a hypothetical?
            if ~ hypothetical_cell
                % Does this cell exist?
                if cell_number>obj.nr_cells
                    disp(['This cell does not exist, there are/is only ' num2str(obj.nr_cells) ' cell(s) in this dataset.'])
                    return;
                end

                % Make indexer for this cell
                if ~isnan(cell_number)
                    indexer = obj.cells==cell_number;
                else % user put NaN, and want's all traces
                    indexer = ~isnan(obj.cells); %nan cells are noise
                end
            else
                indexer = cell_number;
                cell_number = 0;
            end
            
            % If there are to many waveforms we will plot only 5% of them
            % to maintain performance
            cutoff = obj.settings.disp_cutoff;
            original_indexer = indexer; % To be used for histogram for instance
            if sum(indexer)>cutoff && disp_fraction ==1
                disp_fraction = 20;
                disp(['Showing only 5% (n = ' num2str(sum(indexer==1)) ') of all waveforms.'])
            end
            
            % This is to plot only a certain fraction of all waveforms,
            % either because there are more waveforms than the cutoff or
            % because the user specifically requested it.
            new_indexer = zeros(size(indexer));
            new_indexer(1:disp_fraction:end) = indexer(1:disp_fraction:end);
            indexer = logical(new_indexer);
            
            % How to name the figure
            if isnan(cell_number)
                figure_name = 'All Waveforms';
            elseif cell_number==0
                figure_name = 'Unclustered';
            else
                figure_name = ['Cell ' num2str(cell_number)];
            end
            
            % Work on the xaxis
            interval = 10^6/obj.raw_data.hdr.SamplingFrequency; %µs
            timeline = [0:interval:1000-interval]';
            
            % Figure out the cell color
            cell_color = obj.settings.colorlist(cell_number+1);
            
            % Make a figure and plot the waveforms
            waveform_figure = figure('Name',figure_name,...
                'Position',[232, 300, 800, 600]);
            for i=1:4
                subplot(2,2,i)
                ydata = squeeze(obj.data(i,:,indexer)).*obj.settings.ADBitVolts(i)*10^6; % Data from bitvalues to µV
                
                % In the special case that there is only one waveform, make
                % sure that Y is still oriented in the right way
                if sum(indexer)==1
                    ydata = ydata';
                end
                
                % Plot average instead of all sweeps?
                if plot_average
                    stdev_y = std(ydata');
                    ydata = mean(ydata,2);
                    
                    % Plot the stdev shadow
                    fill([timeline', flipud(timeline)'], [ydata'-stdev_y, fliplr(ydata'+stdev_y)],[1 0 0],...
                        'FaceColor',cell_color,...
                        'linestyle','none',...
                        'FaceAlpha',0.1)
                    hold on   
                end
                
                % Plot the data
                xdata = repmat(timeline,1, size(ydata,2),1); % Timeline in µs
                
                % Convert the data for faster performance
                xdata = [xdata; nan(1,size(xdata,2))];
                xdata = xdata(:);
                ydata = [ydata; nan(1,size(ydata,2))];
                ydata = ydata(:);
                
                % Plot the data
                plot(xdata, ydata, 'Color', cell_color);
                hold on
                xlabel('Time (µs)')
                ylabel('Voltage (µv)')
                %ylim([-obj.settings.InputRange(i) obj.settings.InputRange(i)])
                title(['Electrode ' num2str(i)]);
                
                % Plot the threshold line
                line(get(gca,'XLim'), [obj.settings.ThresVal(i), obj.settings.ThresVal(i)],...
                    'Color',[0.2 0.2 0.2],...
                    'LineStyle','--');
            end
            
            % IMPORTANT NOTE: all analysis bellow this point should be done
            % using the original_indexer. The 'indexer' is only used for
            % display purpouses.
            
            % Work on the inter-spike histogram
            histogram_figure = figure('Name','cluster data',...
                'Position',[1033 300, 800, 600]);
            m_timestamps = obj.timestamps(original_indexer);
            intervals = double(m_timestamps(2:end)-m_timestamps(1:end-1));
            subplot(2,2,1);
            histogram(intervals,5000);
            set(gca,'XScale','log')
            xlabel('Interval (µs)')
            ylabel('Count #')
            title('ISI')
            grab_lim = xlim();
            xlim([10^2 grab_lim(2)]);
            line([1000 1000],ylim(),'Color',[1 0 0])
            
            
            % Plot the waveform count throughout the session (to check if
            % stable firing or appearing/disappearing througout the session.
            subplot(2,2,2);
            session_time = obj.settings.recording_interval;
            m_timestamps = double(m_timestamps - session_time(1)).*10^-6;
            session_time = double(session_time - session_time(1)).*10^-6;
            histogram(m_timestamps, 100)
            xlim(session_time)
            xlabel('Time (s)')
            ylabel('Count #')
            title('Firing Distribution')
     
            
            % Calculate the Mahalanobis distance between the center of this
            % cluster and every other spike and compare this to every other
            % spike in the tetrode object for good measure.
            start_index = obj.settings.interval(1);
            end_index = obj.settings.interval(2);
            ydata = [];
            for i=1:4
                % don't include broken electrodes
                if ~obj.settings.working_electrodes(i)
                    continue;
                end
                
                % grab all the ydata
                ydata_temp = squeeze(obj.data(i,start_index:end_index,:)).*obj.settings.ADBitVolts(i)*10^6; % Data from bitvalues to µV
                ydata = [ydata, ydata_temp']; % Matlab Mahalanobis function wants n x m.
            end
            
            % If there are enough sweeps we can plot the Mahalanobis
            % distance
            if size(ydata(original_indexer,:),1)>size(ydata(original_indexer,:),2)
                 
                % Calculate Mahalanobis distance
                d2 = mahal(ydata, ydata(original_indexer,:));
                d2_cell = d2(original_indexer);
                d2_not_cell = d2(~original_indexer(:) & ~isnan(obj.cells(:)));
                d2_including_noise = d2(~original_indexer);

                % We have to trow out outliers because otherwise the histograms
                % are just un-interpetable. Note that we don't do this for the
                % d2_cell, because in that case the hole point is that we want
                % to see the outliers
                d2_not_cell = d2_not_cell(~isoutlier(d2_not_cell));
                d2_including_noise = d2_including_noise(~isoutlier(d2_including_noise));

                % Plot the histograms
                subplot(2,2,3);
                h1 = histogram(d2_cell,...
                    'Normalization','probability',...
                    'DisplayName','Selected Unit');
                hold on
                h2 = histogram(d2_not_cell,...
                    'Normalization','probability',...
                    'DisplayName','Other Waveforms'); 
                h3 = histogram(d2_including_noise,...
                    'Normalization','probability',...
                    'DisplayName','Other Including Removed Waveforms');
                
                try
                    xlim([0 max([mean(d2_cell)+3*std(d2_cell),...
                        mean(d2_not_cell)+3*std(d2_not_cell),...
                        mean(d2_including_noise)+3*std(d2_including_noise)])])
                catch
                    warning('Unable to plot Mahalanobix histogram.')
                end
                xlabel('Mahalanobis distance')
                ylabel('probability')
                legend();
                title('Distance from unit')
                
                % Figure out which one has the smaller binsize and make
                % them similar
                binWidth = min([h1.BinWidth, h2.BinWidth, h3.BinWidth]);
                h1.BinWidth = binWidth;
                h2.BinWidth = binWidth;
                h3.BinWidth = binWidth;
            end
            
            % And finally, we also plot peak hight througout the
            % session for every electrode.
            subplot(2,2,4)
            %smooth_factor = round(0.05 * sum(original_indexer));
            for i=1:4
                plot(m_timestamps, obj.attributes(i).peak(original_indexer),'.',...
                    'DisplayName',['Electrode ' num2str(i)])
                hold on
            end
            xlim(session_time)
            xlabel('Time (s)')
            ylabel('Peak (µV)')
            title(['Peak Stability'])
            legend();
        end
        
        function [plot_handle, results] = peri_event(obj, stamps, varargin)
            % PERI_EVENT_PLOT_STAMPS present a peri-event plot of events
            % stamps. The stamps that will be used as the '0' timepoint are
            % in the variable 'stamps' (1D). All clusters as well as
            % non-clustered events will be ploted in different colors, they
            % are in the 3rd dimension in the results output.
            %
            % By default the nr of bins is 50 (bin width is dynamic) but
            % the nr of bins can be reset with the 'bins' arguments.
            %
            % Results is organized as follows: (trials, time bins, data
            % sets); There is a TIMELINE in the top row!
            %
            % Note that the stamps should the in the same unit of time
            % (e.g. us) as the data in the tetrode object.
            
            % Error handeling
            %       TO DO...  
            
            % CHECK IF DOUBLE AND UINT64 IS REALLY THE SAME
            
            % Deal with input arguments
            window = []; % Plot window
            cell_nr = []; % Cells to be analysed
            nr_bins = 50; % Number of bins
            graph_bars = false; % Showing mean +/- SEM, not bars
            for i = 1:length(varargin)
                switch varargin{i}
                    
                    % Skipp this argument
                    case 'skipp'
                        skippy = 5;
                        
                    % Set the windowsize
                    case 'window'
                        window = varargin{i+1};
                        disp(['Window set to ' num2str(window) 'µs.'])
                        varargin{i+1} = 'skipp';
                        
                    % Set number of bins
                    case 'bins'
                        nr_bins = varargin{i+1};
                        disp(['Data sorted in ' num2str(nr_bins) 'bins.'])
                        varargin{i+1} = 'skipp';    
                    
                    % Only a specific cell
                    case 'cell'
                        cell_nr = varargin{i+1};
                        if ~isempty(cell_nr)
                            disp(['Only plotting cell ' num2str(cell_nr)]);
                        else
                            disp(['Plotting all cells.'])
                        end
                        varargin{i+1} = 'skipp';
                        
                    % Plot bars instead of mean +/- SEM
                    case 'bars'
                        graph_bars = true;
                        
                    otherwise
                        warning('Unknown argument,... ignored.')
                end
            end
            
            % Colorlist for the markers
            temp_colorlist = obj.settings.colorlist;
            
            % check the input arguments
            if strcmp(class(stamps),'uint64')
                stamps = double(stamps);
            end
            
            % Collect the data to be plotted and also figure out the
            % correct color for each cell.
            if isempty(cell_nr) % Do all cells
                cell_nr = [0:obj.nr_cells];
            end
            units = cell(length(cell_nr), 1);
            for i = 1:length(cell_nr)
                units{i} = double(obj.timestamps(obj.cells==cell_nr(i)));
                colorlist(i) = temp_colorlist(cell_nr(i) + 1);
            end
            
            % Error handeling on the intervals. Note that intervals 1000µs
            % are just probably some sort of error, but we should put out a
            % warning.
            intervals = stamps(2:end) - stamps(1:end-1);
            error_intervals = [intervals<1000, false];
            if sum(error_intervals)>0
                warning('Intervals <1000µs between stamps not analyzed.')
                stamps = stamps(~error_intervals);
            end
            intervals = stamps(2:end) - stamps(1:end-1);
            
            % Figure out the appropriate window size
            if isempty(window)
                % Find the smallest inter-stamp interval
                window = round(0.5*(min(intervals)));
            end
            
            % Print the window size
            disp(['Window set to ' num2str(window) 'µs'])
            
            % Figure out an appropriate bin size for the histogram
            bin_size = 2*window/nr_bins;
            timeline = round([-window:bin_size:window-bin_size]+0.5*bin_size,2);
            
            % Make the figure
            plot_handle = figure;
            subplot(2,1,1)
            
            % Make an empty results variable
            results = zeros(length(stamps) + 1, nr_bins, length(units));
            
            % for every dataset
            for i = 1:length(units)
                
                % Add the timeline in the first row of the results
                results(1,:,i) = timeline;
                
                % for every trial
                % Start at row 2 because timeline in row 1
                for j = 2:length(stamps) + 1
                    
                    % Substract the trial from the input data to get the
                    % difference
                    temp_data = units{i} - stamps(j-1);

                    % for every bin
                    for k = 1:length(timeline)
                        
                        % Collect results
                        % note the biger-or-equal on one side, vs smaller
                        % on the other side
                        results(j,k,i) = sum(temp_data>=timeline(k)-0.5*bin_size & temp_data<timeline(k)+0.5*bin_size);
                    end
                    
                    % Plot the events
                    super_temp = temp_data(temp_data>= -window & temp_data< window);
                    plot(super_temp,ones(length(super_temp),1)*(j-1),'.',...
                        'MarkerEdgeColor',colorlist(i),...
                        'MarkerFaceColor',colorlist(i),...
                        'Marker','square',...
                        'MarkerSize', 3);
                    hold on
                end
            end
            
            % Axis labeling etc.
            xlabel('Time (µs)')
            ylabel('Trial #')
            set(gca,'Ydir','reverse')
            set(gca,'Box','off')
            set(gca,'TickLength',[0 0])
            xlim([-window, window])
            
            % Give the figure the right name
            if length(units)==1
                plot_handle.Name = ['Cell: ' num2str(cell_nr)];
                title(['Rasterplot for cell: ' num2str(cell_nr)])
            else
                plot_handle.Name = 'All cells';
                title(['Rasterplot for multiple cells'])
            end
                
            % Plot the histogram below
            subplot(2,1,2)
            
            % Collect the results
            results(2:end,:,:) = results(2:end,:,:)./bin_size;
            
            % Switch from µs to sec (we want the final results in Hz)
            results(2:end,:,:) = results(2:end,:,:).*1000000;
            
            % Calculate mean and SEM and plot
            for i = 1:length(units)
                
                % use a secondary y axis if there are only 2 cells
                if length(units)==2 && i==2
                    yyaxis right
                end
                    
                temp_results = results(2:end,:,i);
                sem_results=std(temp_results)./sqrt(length(stamps));
                
                % plot the mean +/- SEM unless the user requested a bars
                if ~graph_bars
                    fill([timeline';flipud(timeline')],[mean(temp_results)'-sem_results';flipud(mean(temp_results)'+sem_results')],[0 0 1],...
                        'linestyle','none',...
                        'FaceAlpha',0.1,...
                        'FaceColor',colorlist(i));
                    hold on
                    plot(timeline, mean(temp_results),...
                        'Color',colorlist(i),...
                        'DisplayName',['Cell: ' num2str(cell_nr(i))])
                else % bar plot
                    bar_plot = bar(timeline, mean(temp_results),...
                        'FaceColor',colorlist(i),...
                        'BarWidth',0.95,...
                        'DisplayName',['Cell: ' num2str(cell_nr(i))]);

                end
                    
                % Axis labeling etc.
                set(gca,'Box','off')
                set(gca,'TickLength',[0 0])
                xlabel('Time (µs)')
                ylabel('Events (Hz)')
                
                % There is no need for the yaxis ever to be below 0
                temp = ylim(); temp(1) = max([0, temp(1)]); ylim(temp);
                
            end
            
        end
        
        function set_interval(obj, interval)
            %SET_INTERVAL sets the interval that is used to calculate the
            %attributes (for instance only the first 20 datapoints: [0 20];
            
            %   Error handeling
            if length(interval)~=2
                error('Please provide an interval like this [start stop] (in datapoints)')
            end
            
            % Set the interval
            obj.settings.interval = interval;
            
            % Force recalculation of attributes
            obj.find_attributes;
            
        end
        
        function [removed, removed_indexer] = set_offline_threshold(obj, threshold)
            % Applies an offline threshold to each electrode seperataly.
            % This threshold can not be lower than what was used to collect
            % the original tetrode file. The method will allow it, but
            % nothing will happen. The output 'removed' is a bool on wheter
            % or not any waveforms were actually removed from the data.
            %
            % Example: >> obj.set_offlinse_threshold([65 65 65 65]); Will
            % set a threshold of 65µV to each electrode and delete all
            % waveforms that don't make this threshold on any electrode.
            
            % Convert the data to µV
            m_data = obj.data;
            for i=1:4
                m_data(i,:,:) = m_data(i,:,:).*obj.settings.ADBitVolts(i)*10^6;
            end
            
            % WHY DID I DO IT LIKE THAT AND NOT THE OTHER WAY AROUND? IT
            % SEEMS MORE EFFICIENT TO CONVERT THE THRESHOLD INSTEAD?
            
            % See if any sweeps do not meet the new threshold
            indexer = true(size(m_data,3),1);
            for i = 1:4
                indexer(max(squeeze(m_data(i,:,:)))>=threshold(i)) = false;
            end
            
            % Don't try to remove sweeps that are allready removed
            indexer(isnan(obj.cells)) = false;
            
            % Indexer is now true for sweeps that do not meet the threshold
            % on any electrorde
            [removed, removed_indexer] = obj.remove_noise('indexer', indexer);
            
            if removed
                obj.settings.ThresVal = threshold;
            end 
        end
        
        function [coeff, score, explained, main_figure] = full_pca(obj)
            %FULL_PCA does a PCA over all data, independend of electrode
            %   First concatenates all electrodes into one long waveform
            %   for every sample, then performs pca over this data. This
            %   analylsis ignores the individual electrodes after and can
            %   even be perfomed on single-electrode recordings.
            
            % Find the interval
            start = obj.settings.interval(1);
            stop = obj.settings.interval(2);
            disp(['Using the datapoint between ' num2str(start) ' and ' num2str(stop) '.']);
            
            % Concatenate the data from the individual electrodes
            new_data = [];
            for i=1:4
                % don't include broken electrodes
                if ~obj.settings.working_electrodes(i)
                    continue;
                end
                
                new_data = [new_data, squeeze(obj.data(i,start:stop,:))'];
            end
            
            % Don't include removed sweeps in the PCA
            new_data(isnan(obj.cells),:) = nan;
            
            % Do the PCA
            [coeff, score, ~, ~, explained] = pca(new_data);
            
            % Print info
            disp(['First 3 coefficients explain ' num2str(sum(explained(1:3))) '% of the varation.'])
            
            % Make figure, print the waveforms in PCA space
            main_figure = figure();
            main_figure.Position(3:4) = [1200, 400];
            subplot(1,3,1)
            scatter(score(:,1), score(:,2));
            xlabel('1st Principal Component')
            ylabel('2nd Principal Component')
            subplot(1,3,2)
            scatter(score(:,1), score(:,3));
            xlabel('1st Principal Component')
            ylabel('3nd Principal Component')
            subplot(1,3,3)
            scatter(score(:,2), score(:,3));
            xlabel('2st Principal Component')
            ylabel('3nd Principal Component')
            
            % Plot scatter3
            figure
            scatter3(score(:,1),score(:,2),score(:,3))
            hold on
            xlabel('1st Principal Component')
            ylabel('2nd Principal Component')
            zlabel('3nd Principal Component')
            
            % Plot identified clusters
            for i=1:obj.nr_cells
                indexer = obj.cells==i;
                scatter3(score(indexer,1), score(indexer,2), score(indexer,3))
            end 
        end
        
        function save_data(obj, filename, varargin)
            %SAVE will save the object to a .mat file with the name
            %'filename'. The input arguments 'small' saves the tetrode
            %without the raw data sweeps.
            
            % Deal with the input arguments
            for i = 1:length(varargin)
                
                small_data = false;
                switch varargin{i}
                    case 'skipp'
                        % do nothing
                        X=5;
                        
                    case 'small'
                        small_data = true;
                        
                    otherwise
                        disp(['Unknown input arguments: ' varargin{i}]);
                end
                
            end
            
            variable_name = genvarname(filename);
            eval([variable_name '=obj;']);
            
            if small_data
                eval([variable_name '.raw_data = []'])
            end
            
            
            save(filename, variable_name);
            
            
        end
        
        function remove_cell(obj, cell_number)
            %REMOVE_CELL labeles datapoints in that unit as unclustered
            
            % Grab the indexer
            indexer = obj.cells == cell_number;
            indexer2 = obj.cells>cell_number;
            
            % Uncluster the datapoints
            obj.cells(indexer) = 0;
            
            % Decrease all other cell numbers
            obj.cells(indexer2) = obj.cells(indexer2)-1;
            obj.nr_cells = obj.nr_cells-1;

            
        end
        
        function merge_cells(obj, cell_1, cell_2)
            % MERGE_CELLS merges two cells together into one
            % Input should be two cells numbers, after this method they
            % will both be known by the lowest number.
            
            % Error handeling
            if length(cell_1)~=1 || length(cell_2)~=1
                error('Input should be just 2 cell numbers.')
            end
            
            % Figure out the lowest cell index
            new_number = min([cell_1, cell_2]);
            
            % Renumber the cells
            obj.cells(obj.cells==cell_1 | obj.cells==cell_2) = new_number;
            
            % Decrease the cell number of all cells with a higher index
            obj.cells(obj.cells>max([cell_1, cell_2])) = obj.cells(obj.cells>max([cell_1, cell_2]))-1;
            
            % Update the total number of cells
            obj.nr_cells = max(obj.cells);
            
        end
        
        function edit_notes(obj)
            
            % Make a figure for the notepad
            stop_figure = figure('Menubar','none');
            stop_figure.Position(3:4) = [300, 400];
            
            % Some text above
            uicontrol(stop_figure,...
                'Style','text',...
                'String','Add notes below: ',...
                'Units','normalize',...
                'Position',[0.1 0.85 0.8 0.1],...
                'HorizontalAlignment','left');

            % Add the notepad itself
            uicontrol(stop_figure,...
                    'Style','edit',...
                    'Units','normalized',...
                    'Position',[0.1 0.1 0.8 0.8],...
                    'Max', 100,...
                    'HorizontalAlignment','left',...
                    'String',obj.notes,...
                    'Callback', @obj.update_notes);
                
           % Note that the updating of the notes property is done by the
           % Callback.

        end
        
        function backwards_comp(obj)
            % BACKWARDS_COMP ensures backwards compatability to saved
            % objects that are made with an older version of this class.
            %
            % Mostly it runs code that is in the constructor in the current
            % version.
            
            % Find the recording interval
            obj.settings.recording_interval =...
                [obj.raw_data.hdr.FirstTimeStamp, obj.raw_data.hdr.LastTimeStamp];
            
            % Fill out the settings
            %obj.settings.interval = [1, size(obj.raw_data.dat,2)];
            obj.settings.interval = [1, 20];
            obj.settings.preferred_electrodes = [1 2 3]; % Because humans like three dimensions
            obj.settings.colorlist = ['kgrbmycgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbmgrbmycgrbm'];
            
            % Figure out which electrodes are not recording anything at all
            % and label them 'false' in the working electrodes property
            for i=1:4
                if sum(sum(obj.data(i,:,:)))==0
                    obj.settings.working_electrodes(i) = false;
                else
                    obj.settings.working_electrodes(i) = true;
                end
            end
            
        end
        
        function set_5sigma_threshold(obj)
            % Will set the threshold post-hoc to 5 sigma. The sigma is
            % calculated using the last 2 datapoints of a sweep. The
            % formula used to calculate 5sigma is: 
            % sigma = median(abs(x)/.6745)
            
            new_threshold = [0 0 0 0];
            
            % Calculate the sigma for each channel.
            for i=1:4
                if obj.settings.working_electrodes(i)
                    data = obj.data(i,end-2:end,:);
                    new_threshold(i) = 5*median(abs(data(:)/0.6745));
                else % if electrode is broken
                    new_threshold(i) = inf;
                end
            end
            
            % Convert to µV using the ADBitVolt value.
            new_threshold = new_threshold.*(obj.settings.ADBitVolts(i)*10^6);
            
            % Apply the threshold
            removed = obj.set_offline_threshold(new_threshold);
            
            % Print the final threshold
            if removed
                disp(['Threshold set to : ' num2str(new_threshold) ' µV']);
            else
                disp('No new threshold set')
            end
            
        end
        
        function [overview, D2] = unit_quality(obj, varargin)
            %UNIT_QUALITY will calculate an overview of the quality
            % parameters for all identified units.
            %
            % L-ratio and isolation distance are based on:
            % Schmitzer-Torbert et al. Neuroscience 2005.
            %
            % A second output argument is the D2 matrix with the
            % Mahalanobis distance to each cluster for each waveform as
            % calulated using a feature vector including energy and
            % energy-normalized PCA (1st coefficient). 
            %
            % The input arguments option 'exclude' follwed by an indexer of
            % of the same length as the nr of waveforms will exclude all
            % waveforms that have true in this indexer.
            
            % Look at the input arguments
            excluder = false(size(obj.cells));
            for i=1:length(varargin)
                
                switch varargin{i}
                    
                    case 'skipp'
                        % Skipp this argument
                        continue
                        
                    case 'exclude'
                        % Use an indexer to exclude a bunch of waveforms
                        excluder = varargin{i+1};
                        varargin{i+1} = 'skipp';
                    
                    otherwise
                        disp(['Unknown argmument: ' varargin{i} ' ...ignored.'])
                end
            end
            
            % Analyse the following interval
            start = obj.settings.interval(1);
            stop = obj.settings.interval(2);
            
            % Print some important text
            disp(' ');
            disp([' ***** printing unit quality based on the datapoints: ' num2str(start) ':' num2str(stop) ' ***** '])
            disp('L-ratio and isolation distance based on normalized PCA and energy according to Schmitzer-Torbert et al. Neuroscience 2005')
            disp(' ');
            disp('L_ratio and isolation distance raw are based on the entire waveform, and not the 8-dimensional feature vector.')
            disp(' ');
            
            % Make sure to update the waveform attributes
            obj.find_attributes();
            
            % Make a feature fector for each waveform
            f_vector = [obj.attributes(1).norm_pca_1',...
                obj.attributes(2).norm_pca_1',...
                obj.attributes(3).norm_pca_1',...
                obj.attributes(4).norm_pca_1',...
                obj.attributes(1).energy',...
                obj.attributes(2).energy',...
                obj.attributes(3).energy',...
                obj.attributes(4).energy'];
            
            % Figure out the broken electrodes and don't include them
            working_electrodes = obj.settings.working_electrodes;
            working_electrodes = [working_electrodes, working_electrodes];
            f_vector = f_vector(:, working_electrodes);
            
            % Make a concatenated waveform over all working electrodes
            con_wave = [];
            for i=1:4
                % don't include broken electrodes
                if ~obj.settings.working_electrodes(i)
                    continue;
                end
                
                con_wave = [con_wave, squeeze(obj.data(i,start:stop,:))'];
            end
            
            % Let's grab all the data we need and exclude any waveforms if
            % the user requested that using the 'exclude' flag.
            f_vector = f_vector(~excluder,:);
            con_wave = con_wave(~excluder,:);
            
            % For every unit
            for i=1:obj.nr_cells
                % Unit number
                overview(i).unit_nr = i;
                
                % Make the indexer
                indexer = obj.cells == i;
                indexer(excluder) = false; % apply the excluder
                
                % Nr op spikes
                overview(i).nr_spikes = sum(indexer);
                
                % Average firing rate
                total_time = (double(obj.timestamps(end)) - double(obj.timestamps(1)))*10^-6;
                overview(i).firing_rate = overview(i).nr_spikes/total_time;
                
                % Find the channel where the waveform has most energy
                energy_per_channel = zeros(4,1);
                for j=1:4
                    energy_per_channel(j) = mean(obj.attributes(j).energy(indexer));
                end
                [~, max_energy] = max(energy_per_channel);
                
                % Find the archetype waveform
                overview(i).waveform = mean(squeeze(obj.data(max_energy,:,indexer)),2);
                
                % AP width
                [~, AP_start] = min(overview(i).waveform(1:8));
                [~, AP_end] = min(overview(i).waveform(9:20));
                AP_end = AP_end + 8;
                AP_width = AP_end - AP_start;
                overview(i).AP_width = AP_width * 1/obj.raw_data.hdr.SamplingFrequency * 10^6;
                
                % Average peak height
                distance_from_origin(i) = 0;
                for j = 1:4
                    if working_electrodes(j)
                        height = mean(obj.attributes(j).height(indexer));
                        overview(i).(['height_' num2str(j)]) = height;
                        distance_from_origin(i) = distance_from_origin(i) + height^2;
                    else
                        overview(i).(['height_' num2str(j)]) = nan;
                    end
                end
                distance_from_origin(i) = sqrt(distance_from_origin(i));
                
                % Stability on each electrode
                for j = 1:4
                    if working_electrodes(j)
                        overview(i).(['std_' num2str(j)]) = std(obj.attributes(j).height(indexer));
                    else
                        overview(i).(['std_' num2str(j)]) = nan;
                    end
                end
                    
                % Mahalanobis distance of each waveform to the center of
                % this cluster based on the 8 criteria by Schmitzer-Torbert
                % et al. Neuroscience 2005
                
                % Remove all datapoints from the indexer that were exluded
                % (they are allready excluded from f_vector and con_wave
                % anyway.)
                
                indexer = indexer(~excluder);
                
                if size(f_vector,2)<sum(indexer)
                    D2(:,i) = mahal(f_vector, f_vector(indexer,:));

                    % For eacht waveform that is NOT part of this cluster
                    % (~indexer) calculate the probability of finding int based
                    % on how far away from the center it is (D2 = mahalanobis
                    % distance from center of cluster). The degrees of freedom
                    % is the number of features (2 * the number of working
                    % electrodes). 2 because PC1 and Energy. (Note that
                    % working_electrodes is allready a boolean of length 8
                    % so we don't have to double it here.)
                    v = sum(working_electrodes);
                    overview(i).L_C = sum(1 - chi2cdf(D2(~indexer,i), v));

                    % Divide this by the number of waveforms in the cluster to
                    % get the L_ratio.
                    overview(i).L_ratio = overview(i).L_C/sum(indexer);
                
                    % Isolation distance
                    temp_D2 = sort(D2(~indexer));
                    if length(temp_D2)>sum(indexer)+1
                        overview(i).I_Dst = temp_D2(sum(indexer)+1);
                    else
                        overview(i).I_Dst = nan;
                    end
                    
                else
                    overview(i).L_C = nan;
                    overview(i).L_ratio = nan;
                    overview(i).I_Dst = nan;
                end
                
                % Same thing, but now on the 'raw' waveform, but only if
                % enough waveforms are available.
                if size(con_wave,2)<sum(indexer)
                    D2_raw(:,i) = mahal(con_wave, con_wave(indexer,:));
                    v = size(con_wave,2);
                    overview(i).L_C_raw = sum(1 - chi2cdf(D2_raw(~indexer,i), v));
                    overview(i).L_ratio_raw = overview(i).L_C_raw/sum(indexer);
                    temp_D2 = sort(D2_raw(~indexer));
                    if length(temp_D2)>sum(indexer)+1
                        overview(i).I_Dst_raw = temp_D2(sum(indexer)+1);
                    else
                        overview(i).I_Dst_raw = nan;
                    end
                else
                    overview(i).L_C_raw = nan;
                    overview(i).L_ratio_raw = nan;
                    overview(i).I_Dst_raw = nan;
                end
                
            end
            
            % Mark the unit closest the the origin as the most likely
            % multi-unit remainder.
            [~, index] = min(distance_from_origin);
            
            % UNLESS the average of unclusered and noise (nan) waveforms is
            % actually closer to the origin.
            overview(index).multiunit = 'Likely Mutiunit';
            
        end
        
        function remove_permanent(obj)
            %  REMOVE_PERMANENT removes all NaN waveforms permanent from
            %  the object. They are also no longer included when
            %  calculating L-Ratio or other quality parameters. It is
            %  important to run this method only after marking clear noise
            %  waveforms, such as clipped waveforms or below-threshold
            %  waveforms.
            
            % Find the index of all NaN waveforms
            indexer = ~isnan(obj.cells);
            
            % Remove all NaN data
            obj.cells = obj.cells(indexer);
            obj.timestamps = obj.timestamps(indexer);
            obj.data = obj.data(:,:,indexer);
            
            %Find all attributes again
            obj.find_attributes();
            
        end
        
        function remove_raw(obj)
            %REMOVE_RAW removes all raw data. This is sometimes neccesary
            %when there is simply to much raw data and the CPU is unable to
            %deal with it smoothly.
            
            % Grab the hdr from the raw data
            temp = obj.raw_data.hdr;
            
            % Remove all raw data
            obj.raw_data = [];
            
            % Put the header back
            obj.raw_data.hdr = temp;
            
            
        end
        
        function update_han(obj)
            % Will update the tetrode to make it consistent with current
            % data standards.
            
            indexer = isnan(obj.cells);
            obj.cells(indexer) = 99;
            obj.remove_noise('clipping');
            close all
            obj.set_5sigma_threshold();
            obj.remove_permanent();
            obj.cells(obj.cells==99) = nan;
            
            
        end
    end
    
    % Methods that relate to file import and output
    methods (Access = private)
        
        function read_raw_CSC_signals(filenames, sigma_factor)
            % READ_RAW_CSC_SIGNALS read Neuralynx .ncs files and performs
            % the following actions.
            %
            %   1. Import the files in 'filename'
            %   2. Calculate the treshold for eachn signal:
            %           sigma_factor * sigma; where sigma is:
            %           median(abs(signal/0.6745))
            %   3. Find every data point above the threshold
            %   4. Allign peaks close to threshold crosovers
            %   5. ...
            
            
            
            
            
            
        end
        
    end
    
    % Callbacks and other functions
    methods (Access = private)
        
        function update_notes(obj, src, ev)
            
            obj.notes = src.String;

        end
        
        function check_object(obj)
            % CHECK_OBJECT can be called when there is a risk of
            % inconsistencies or failures in the object configuration. It
            % will make sure all the properties are in line with each
            % other.
            
            % Check the total number of cells
            obj.nr_cells = max(obj.cells);
            
            % TODO more error handeling
            
        end
   
    end
end

