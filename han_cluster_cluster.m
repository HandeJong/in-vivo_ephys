%% Start
clear all
close all
clc


%% variables
filename = 'TT5.NTT';
interval = [1 25];
cluster_attribute = 'height';
automated_clustering = false;
nr_clusters = [2 8];
opto_tagging = true;
threshold_method = '5sigma';
%threshold_method = 'other';
%show_electrodes = [1 2 3];


%% Load the tetrode
Tetrode = tetrode(filename);
Tetrode.set_interval(interval);
Tetrode.settings.disp_cutoff = 50000;

% Just grab the prefered electrodes from the tetrode
show_electrodes = Tetrode.settings.preferred_electrodes;

% Open the notepad
Tetrode.edit_notes;


%% Remove noise (mostly lickometer)
Tetrode.remove_noise('clipping');


%% Set an offline threshold
if strcmp(threshold_method, '5sigma')
    Tetrode.set_5sigma_threshold();
    
else
    % Keep increasing the threshold untill the user says stop.
    threshold = Tetrode.settings.ThresVal;
    keep_running = true;
    while(keep_running)
        threshold = threshold + 5;
        keep_running = Tetrode.set_offline_threshold(threshold);
    end

    disp(['Final threshold set to : ' num2str(threshold-5) ' nµV']);
end


%% Permanently remove the sweeps marked noise by now
Tetrode.remove_permanent();


%% Present the original figure and set interval
Tetrode.set_interval(interval);
[precluster_figure_1, precluster_figure_2] = Tetrode.present_figure('height', show_electrodes);
    

%% Cluster
if automated_clustering
    automated_clustering = true; %for quick-select
    new_cells = cluster_han(cluster_attribute, Tetrode, 'auto_gm', nr_clusters);
    automated_clustering = false; % for next round
else
    new_cells = cluster_han(cluster_attribute, Tetrode);
end

% Figure out new NaN values
new_noise = isnan(new_cells);
new_noise(isnan(Tetrode.cells)) = false;

% Remove waveforms labeled as noise (but check with the user).
if sum(new_noise)>0
    Tetrode.remove_noise('indexer', new_noise);
end

% Update the cells property
Tetrode.cells(~new_noise) = new_cells(~new_noise);
Tetrode.nr_cells = max(Tetrode.cells);    


%% Close the previous figures
close(precluster_figure_1)
close(precluster_figure_2)


%% Print the current clustogram
Tetrode.present_figure('height', show_electrodes);


%% Check if any of the cells are tagged
if opto_tagging
    events = read_neuralynx_nev('Events.nev');
    for i=1:length(events)
        timestamps(i) = events(i).TimeStamp;
        TTL(i) = events(i).TTLValue;
    end
    stamps = timestamps(TTL==128);
    %stamps = stamps(1:20:end);
    Tetrode.peri_event(stamps,'window',50*10^3);
end


%% Temp, remove added data
if false
    indexer = Tetrode.timestamps>10^9;
    Tetrode.data = Tetrode.data(:,:,indexer);
    Tetrode.timestamps = Tetrode.timestamps(:,indexer);
    Tetrode.cells = Tetrode.cells(:,indexer);
    
    Tetrode.raw_data.Timestamp = Tetrode.raw_data.TimeStamp(:, indexer);
    Tetrode.raw_data.ScNumber = Tetrode.raw_data.ScNumber(:, indexer);
    Tetrode.raw_data.CellNumber = Tetrode.raw_data.CellNumber(:, indexer);
    Tetrode.raw_data.Param = Tetrode.raw_data.Param(:, indexer);
    Tetrode.raw_data.dat = Tetrode.raw_data.dat(:,:,indexer);
    Tetrode.raw_data.NRecords = sum(indexer);
    
    for i=1:4
        Tetrode.attributes(i).peak = Tetrode.attributes(i).peak(:,indexer);
        Tetrode.attributes(i).valley = Tetrode.attributes(i).valley(:,indexer);
        Tetrode.attributes(i).height = Tetrode.attributes(i).height(:,indexer);
        Tetrode.attributes(i).energy = Tetrode.attributes(i).energy(:,indexer);
        Tetrode.attributes(i).pca_1 = Tetrode.attributes(i).pca_1(:,indexer);
        Tetrode.attributes(i).pca_2 = Tetrode.attributes(i).pca_2(:,indexer);
        Tetrode.attributes(i).pca_3 = Tetrode.attributes(i).pca_3(:,indexer);
    end
end
