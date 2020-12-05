function [output] = cluster_han(attribute, tetrode, varargin)
%CLUSTER_HAN is used for manual or automated clustering of the data
%   The data argument can be any of the attributes in the tetrode object.
%   (See the tetrode.attributes property for a list). For instance:
%
%       >> cluster_han('height', tetrode);
%
%   In addition, cluster_han supports clustering on a full_PCA, where the
%   different columns in the data are independend of the electrodes but
%   instead refer to the first three PCs over the entire dataset (all
%   electrodes concatenated).
%
%       >> cluster_han('pca', tetrode);
%
%   It is also possible to perform automated clustering on the basis of
%   mixed Gaussian models, where 'k' is the number of clusters.
%
%       >> k=5;
%       >> cluster_han('pca', tetrode, auto_gm, k);
%
%   Additionally you can have this function figure out how many clusters is
%   probably best on the basis of a Baysian information criterium. To do
%   this, set k to a range to test e.g. 1-15 is [1 15].
%
%       >> cluster_han('pca', tetrode, auto_gm, [1 15]);
%
%   Supported key presses:
%       n:      new polygon
%       c:      close polygon
%       d:      delete last maker
%       space:  cancel polygon
%       a:      show a larger percentage of datapoints
%       z:      show fewer datapoints
%       q:      merge 2 clusters (will promt dialog box)
%       w:      delete cluster (will promt warning dialog)
%       #:      meaning any number 'n' will be the active cluster.
%       e:      show details about cluster
%       r:      re-run automated clustering and/or pca



% Look at variable input arguments
auto_gm = false;
k = 1;
for i = 1:length(varargin)
    
    switch varargin{i}
        
        case 'skipp'
            % Do nothing, skipp this arguments
            hoihoi = 5;
        
        case 'auto_gm'
            auto_gm = true;
            k = varargin{i+1};
            varargin{i+1} = 'skipp';
        
        otherwise
            disp('Unknown argument,.... ignored.')
    end
end


% Empty variables
X = [];
Y = [];
active_cluster = 0;


% Output variable
found_units = tetrode.cells;
nr_cells = max(found_units);


% Grab the colorlist
colorlist = tetrode.settings.colorlist;


% Grab the prefered electrodes
electrodes = tetrode.settings.preferred_electrodes;


% Grab the data we will work with and also store if we used PCA to obtain
% this data.
if strcmp(attribute, 'pca')
    [coeff, score, explained, main_figure] = tetrode.full_pca;
    close(main_figure);
    attribute = score;
    used_pca = true;
else
    attribute = [tetrode.attributes(electrodes(1)).(attribute)',...
        tetrode.attributes(electrodes(2)).(attribute)',...
        tetrode.attributes(electrodes(3)).(attribute)'];
    used_pca = false;
end


% If there are too many waveforms we will plot only 5% of them
% to maintain performance
cutoff = tetrode.settings.disp_cutoff;
disp_fraction = 1;
if sum(~isnan(tetrode.cells))>cutoff
    disp_fraction = 20;
    disp(['Showing only 5% of waveforms/datapoints to maintain performance.'])
end
disp_indexer = false(size(tetrode.cells));
disp_indexer(1:disp_fraction:end) = true;


% Figure out if we are plotting existing clusters or running automated
% clustering (the two are mutually exclusive in this version of the code).
if auto_gm
    automatic_clustering();
end


% Make a figure, plot all the data from 3 different viewpoints, using the
% first 3 columns of the data (first argument). Cluster_han currently
% suports a max of 25 clusters
main_figure = figure;
scatje = cell(3, 26);
for i = 0:25 % For every potential cluster
    indexer = found_units==i;
    indexer(~disp_indexer) = false;
    dataname = ['cell ' num2str(i)];

    subplot(1,3,1)
    scatje{1,i+1} = scatter(attribute(indexer,1), attribute(indexer,2),...
        'DisplayName', dataname,...
        'MarkerEdgeColor',colorlist(i+1),...
        'Visible','off');
    xlabel('Data 1')
    ylabel('Data 2')
    hold on
    subplot(1,3,2)
    scatje{2,i+1} = scatter(attribute(indexer,1), attribute(indexer,3),...
        'DisplayName', dataname,...
        'MarkerEdgeColor',colorlist(i+1),...
        'Visible','off');
    xlabel('Data 1')
    ylabel('Data 3')
    hold on
    subplot(1,3,3)
    scatje{3,i+1} = scatter(attribute(indexer,2), attribute(indexer,3),...
        'DisplayName', dataname,...
        'MarkerEdgeColor',colorlist(i+1),...
        'Visible','off');
    xlabel('Data 2')
    ylabel('Data 3')
    hold on
end


% Update figure, make all previously identified clusters visible
update_figure();


% add callbacks to the figure
main_figure.WindowButtonDownFcn = @mouse_click;
main_figure.WindowKeyPressFcn = @key_press;


% Make the main figure bigger
main_figure.Position = [140, 150, 1600, 500];


% Plot the polygon that the user can manipulate to lock-in datapoitns
figure(main_figure)
hold on
polygon = plot(0,0,'Visible','off','Color',[1, 0.6471, 0]);
drawing_polygon = false;


% Wait for the figure to be closed
% Are we done
we_are_done = false;


% THIS IS WHERE THE PROGRAM WAITS UNTILL YOU CLOSE THE FIGURE
while(~we_are_done)
     % If the figure is closed, end the program
    if ~ishandle(main_figure)
        we_are_done = true;
    end
    
    % quick pause
    pause(0.01);
end


% Store the output
output = found_units;


%%%%%%%%%%%%%%%%%%%%%%%%%%% Nested Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function mouse_click(scr, ev)
        % Deals with mouse input
        p_axis = gca;
        c_point = p_axis.CurrentPoint(1,:);
        X = [X; c_point(1)];
        Y = [Y; c_point(2)];
        
        hold on
        update_polygon;   
 end

function key_press(scr, ev)
        % Deals with key presses
        
        % Check if the key is a number
        if ~isempty(str2num(ev.Key))
            
            active_cluster = str2num(ev.Key);
            update_figure();
            return
        end
        
        switch ev.Key
            case 'd'% Delete last marker
                X = X(1:end-1);
                Y = Y(1:end-1);
                
                if isempty(X)
                    drawing_polygon = false;
                end
                update_polygon();
                
            case 'n' % New polygon
                disp('new polygon')
                X = [];
                Y = [];
                drawing_polygon = true;
                update_polygon();
                
            case 'c' % Close polygon
                X(end+1) = X(1);
                Y(end+1) = Y(1);
                
                close_polygon();
                drawing_polygon = false;
                X = [];
                Y = [];
                update_polygon();
                
            case 'z' % Show smaller percentage of datapoints
                disp_fraction = disp_fraction +1;
                disp(['Showing ' num2str(100/disp_fraction) '% of datapoints.'])
                disp_indexer = false(size(tetrode.cells));
                disp_indexer(1:disp_fraction:end) = true;
                update_figure();
                
            case 'a' % Show larger percentage of datapoints
                disp_fraction = disp_fraction -1;
                disp(['Showing ' num2str(100/disp_fraction) '% of datapoints.'])
                if disp_fraction <1; disp_fraction=1; end
                disp_indexer = false(size(tetrode.cells));
                disp_indexer(1:disp_fraction:end) = true;
                update_figure();
                
            case 'space' % Cancel polygon
                drawing_polygon = false;
                X = [];
                Y = [];
                update_polygon();
                
            case 'r' % Rerunautomated clustering (if applicable)
                
                if auto_gm % do GMMfitting
                    automatic_clustering();
                    update_figure();
                else
                    disp('No automated clustering set.')
                end
                
            case 'e' % Show the active cluster details
                
                indexer = found_units == active_cluster;

                % Show the current points as a hypothethical
                tetrode.show_cell(indexer,'hypothetical');
                
            case 'w' % Delete cluster
                indexer = found_units == active_cluster;
                delete_cluster(indexer);
                % Update figure
                update_figure();

            otherwise
                disp('Key not recognized.')
        end
 end

function update_polygon()
    polygon.Parent = gca;
    polygon.XData = X;
    polygon.YData = Y;
    
    if drawing_polygon
        polygon.Visible='on';
    else
        polygon.Visible='off';
    end

end

function close_polygon()
    
    % find out which axis we are working on
    hax = gca;
    data_X = str2num(hax.XLabel.String(end));
    data_Y = str2num(hax.YLabel.String(end));
    
    % Grab the indexer
    indexer = inpolygon(attribute(:,data_X), attribute(:,data_Y), X, Y);
    
    % Don't recluster the points that are allready labeled
    indexer(found_units~=0) = false;
    
    % Show the current points as a hypothethical
    [figure_1, figure_2] = tetrode.show_cell(indexer,'hypothetical');
    
    % Ask if the user wan't to keep this cell
    something_real = false;
    input = questdlg('Cell or noise?','Cell?','cell','noise','neither','neither');
    switch input
        case 'cell'
            found_units(indexer) = nr_cells+1;
            nr_cells = nr_cells+1;
            use_color = colorlist(nr_cells+1);
            something_real = true;
            
        case 'noise'
            use_color = [1 1 1];
            found_units(indexer) = nan;
            something_real = true;
            
        case 'neither'
           disp('Not clustered')
           something_real = false;
           
        otherwise
            disp(input)
    end
    
    % Close the figures
    close(figure_1)
    close(figure_2)
    
    % Update figure
    update_figure();
    
end

function update_figure()
    for i = 0:max(found_units)
        indexer = found_units==i;
        
        if i == active_cluster
            marker = 'diamond';
        else
            marker = 'o';
        end
        
        % disp_indexer deals with the fraction shown
        indexer(~disp_indexer) = false;
        
        % plot 1
        scatje{1,i+1}.XData = attribute(indexer,1); 
        scatje{1,i+1}.YData = attribute(indexer,2);
        scatje{1,i+1}.Visible = 'on';
        scatje{1,i+1}.Marker = marker;
        
        % plot 2
        scatje{2,i+1}.XData = attribute(indexer,1); 
        scatje{2,i+1}.YData = attribute(indexer,3);
        scatje{2,i+1}.Visible = 'on';
        scatje{2,i+1}.Marker = marker;
        
        % plot 3
        scatje{3,i+1}.XData = attribute(indexer,2); 
        scatje{3,i+1}.YData = attribute(indexer,3);
        scatje{3,i+1}.Visible = 'on';
        scatje{3,i+1}.Marker = marker;
    end  
end

function automatic_clustering()
    % Have to make sure that we don't use empty channels, because a list of
    % 0 will look like a constant column and that will mess up the GMMfit.
    backup_attribute = attribute;
    temp_indexer = mean(attribute)~=0;
    attribute = attribute(:, temp_indexer);
    if sum(~temp_indexer>0)
        disp('Ignored empty channels.')
    end
    
    % Ignore waveforms labeled as NaN (noise). This is automatically done
    % by the full_PCA method, but might have to be redone.
    attribute(isnan(found_units),:) = nan;

    % Did the user give a range or just one value for k?
    if length(k)==2
        
        k = [k(1):k(2)];    
        
        for i = 1:length(k)
            try
                disp(['Fitting GMM with ' num2str(k(i)) ' models....'])
                gm_model{i} = fitgmdist(attribute, k(i));
                BIC(i) = gm_model{i}.BIC;
                disp('...done.')
            catch exception
                warning(['Unable to fit GM model with ' num2str(i) ' models.'])
                disp(exception.message)
                BIC(i) = inf;
            end
        end
        [~, lowest_index] = min(BIC);
        disp(['The best fit based on BIC has ' num2str(gm_model{lowest_index}.NumComponents) ' models.'])
        gm_model = gm_model{lowest_index};
    else
        try
            disp(['Fitting GMM with ' num2str(k) ' models....'])
            gm_model = fitgmdist(attribute, k);
            disp('...done.')
        catch exception
            warning(['Unable to fit GM model with ' num2str(i) ' models.'])
            disp(exception.message)
        end
    end

    % Display some information about the quality of the clustering
    disp('****** Mixed Gaussian Model ******')
    disp(['-Log likelyhood: ' num2str(gm_model.NegativeLogLikelihood)])
    disp(['Number of models: ' num2str(gm_model.NumComponents)])
    disp(['Baysian Information Criterium: ' num2str(gm_model.BIC)])

    % Cluster the cells on the basis of there most likely model
    found_units = cluster(gm_model, attribute);

    % put back the original attribute matrix (which might contain empty
    % channels).
    attribute = backup_attribute;
end

function delete_cluster(indexer)
    % Deletes a cluster meaning that it will store NaN values in the
    % indexer.
    % Show the current points as a hypothethical
    [figure_1, figure_2] = tetrode.show_cell(indexer,'hypothetical');
    
    % Ask if the user wan't to keep this cell
    something_real = false;
    input = questdlg('Are you sure you want to delete?','Cell?','Yes','No','No');
    switch input
        case 'No'
            % do nothing

        case 'Yes'
            disp('here')
            scatje{1,i+1}.Visible = 'off';
            scatje{2,i+1}.Visible = 'off';
            scatje{3,i+1}.Visible = 'off';
            found_units(indexer) = nan;
            something_real = true; 
    end
    
    % Close the figures
    close(figure_1)
    close(figure_2)
    
end
    
end


