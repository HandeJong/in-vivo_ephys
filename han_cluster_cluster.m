%% Start
clear all
close all
clc


%% Make sure all files are on the path

addpath(genpath('C:\Users\Lammel\Documents\MATLAB\in-vivo_ephys-master'))
addpath(genpath('~/Scripts'))

%% variables
filename = 'TT4_hb.ntt';
interval = [1 25];
cluster_attribute = 'pca';
automated_clustering = false;
nr_clusters = [2 8];
opto_tagging = true;
threshold_method = '5sigma';
%threshold_method = 'other';
%show_electrodes = [1 2 3];n


%% Load the tetrode
Tetrode = tetrode(filename);
Tetrode.set_interval(interval);
Tetrode.settings.disp_cutoff = 25000;

% Just grab the prefered electrodes from the tetrode
show_electrodes = Tetrode.settings.preferred_electrodes;

% Open the notepad
Tetrode.edit_notes;


%% Make all meta timestamps
source_TTL = 1;
meta_stamps(Tetrode, source_TTL, 1, 1000); %1ms, 1Hz
meta_stamps(Tetrode, source_TTL, 5, 1000); %5ms, 1Hz
meta_stamps(Tetrode, source_TTL, 1, 50); %1ms, 20Hz
meta_stamps(Tetrode, source_TTL, 5, 50); %5ms, 20Hz
meta_stamps(Tetrode, source_TTL, 5, 500); %5ms, 2Hz 

%% Remove noise (mostly lickometer)
Tetrode.remove_noise('clipping');


% %% Set an offline threshold
% if strcmp(threshold_method, '5sigma')
%     Tetrode.set_5sigma_threshold();
%     
% else
%     % Keep increasing the threshold untill the user says stop.
%     threshold = Tetrode.settings.ThresVal;
%     keep_running = true;
%     while(keep_running)
%         threshold = threshold + 5;
%         keep_running = Tetrode.set_offline_threshold(threshold);
%     end
% 
%     disp(['Final threshold set to : ' num2str(threshold-5) ' nµV']);
% end


%% Permanently remove the sweeps marked noise by now
%Tetrode.remove_permanent();


%% Present the original figure and set interval
%Tetrode.set_interval(interval);
%[precluster_figure_1, precluster_figure_2] = Tetrode.present_figure('height', show_electrodes);


%% Check how many electrodes are working, and if it's only one, cluster on pca
if sum(Tetrode.settings.working_electrodes) == 1
    cluster_attribute = 'pca';
    warning('Clusterin on PCA because only one working electrode.')
end


% %% Cluster
% if automated_clustering
%     automated_clustering = true; %for quick-select
%     new_cells = cluster_han(cluster_attribute, Tetrode, 'auto_gm', nr_clusters);
%     automated_clustering = false; % for next round
% else
%     new_cells = cluster_han(cluster_attribute, Tetrode);
% end
% 
% % Figure out new NaN values
% new_noise = isnan(new_cells);
% new_noise(isnan(Tetrode.cells)) = false;
% 
% % Remove waveforms labeled as noise (but check cuwith the user).
% if sum(new_noise)>0
%     Tetrode.remove_noise('indexer', new_noise);
% end
% 
% % Update the cells property
% Tetrode.cells(~new_noise) = new_cells(~new_noise);
% Tetrode.nr_cells = max(Tetrode.cells);    
% 
% % Start the viewer so the user can inspect
viewer = han_tetrode_viewer(Tetrode);


%% Close the previous figures
% close(precluster_figure_1)
% close(precluster_figure_2)

% 
% %% Run the cutter on every cell
% for i=1:Tetrode.nr_cells
%     cutter_han(Tetrode, i);
% end
% viewer.update_waveforms();

%% Print the current clustogram
% Tetrode.present_figure('height', 'average');


%% Check if any of the cells are tagged
TTL_source = 1;
if opto_tagging
    for i=0:Tetrode.nr_cells
        [~, statistics, ~] = Tetrode.opto_tagged(i, TTL_source);
    end
end


%% Function that will import meta stamps
function meta_stamps(Tetrode, source, duration, interval)

    % Make sure we are looking at the newest version of the TTL info
    if ~isfield(Tetrode.TTL, 'duration')
        obj = Tetrode;
        for i = 1:length(Tetrode.TTL)
            obj.TTL(i).name = 'no name';
            obj.TTL(i).number = length(obj.TTL(i).on);
            obj.TTL(i).duration = round((obj.TTL(i).off - obj.TTL(i).on)*10^-3);
            obj.TTL(i).ave_duration = mean(obj.TTL(i).duration);
            intervals = round(([obj.TTL(i).on(2:end) - obj.TTL(i).on(1:end-1)])*10^-3); 
            obj.TTL(i).interval = [intervals(1), intervals];
            obj.TTL(i).ave_interval = mean(obj.TTL(i).interval);
        end    
    end

    % Figure out the output TTL number
    output = length(Tetrode.TTL)+1;
    
    % Make an indexer for the requested stamps
    indexer = Tetrode.TTL(source).duration==duration;
    indexer(Tetrode.TTL(source).interval~=interval)=false;
    
    % Make the name
    name = [num2str(1000/interval) 'Hz, ' num2str(duration) 'ms'];
    
    % Grab the data from the source
    Tetrode.TTL(output).name = name;
    Tetrode.TTL(output).type = Tetrode.TTL(source).type;
    Tetrode.TTL(output).number = sum(indexer);
    Tetrode.TTL(output).on = Tetrode.TTL(source).on(indexer);
    Tetrode.TTL(output).off = Tetrode.TTL(source).off(indexer);
    Tetrode.TTL(output).duration = Tetrode.TTL(source).duration(indexer);
    Tetrode.TTL(output).ave_duration = mean(Tetrode.TTL(output).duration);
    Tetrode.TTL(output).interval = Tetrode.TTL(source).interval(indexer);
    Tetrode.TTL(output).ave_interval = mean(Tetrode.TTL(output).interval);
end