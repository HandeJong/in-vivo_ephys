%% Start
clear all
close all


%% Varialbes
filename{1} = 'CSC9.ncs';
filename{2} = 'CSC10.ncs';
filename{3} = 'CSC11.ncs';
filename{4} = 'CSC12.ncs';

%% Import data
for i=1:4
    start_time = tic;
    signal{i} = read_neuralynx_ncs(filename{i});
    disp(['File ' filename{i} ' loaded in ' num2str(toc(start_time)) 'sec'])
end


%% Figure out the sigma and the threshold
for i=1:4
    sigma = median(abs(signal{i}.dat(:)/0.6745));
    threshold(i) = 5 * sigma;
    disp(['Treshold for electrode ' num2str(i) ' set to ' num2str(threshold(i)) 'µV.'])
end


%% Grab all the 32
for i=1:4
    final_data{i} = [];
end

data_size = length(signal{1}.dat(:));
temp = round(0.01*data_size);
retrigger_block = 0;
for i=1:length(signal{1}.dat(:))
    if retrigger_block ==0
        if signal{1}.dat(i)>threshold(1)
            try
                % find the closes peak
                [~, shift] = max(signal{1}.dat(i:i+10));
                index = i+shift - 1;
                
                for j=1:4
                    final_data{j} = [final_data{j}; signal{j}.dat(index-7:index+24)];
                end
                retrigger_block = 24; % prevent retrigger
            catch
                disp(['Error at i = ' num2str(i)])
            end
        end
    else
        retrigger_block = retrigger_block -1;
    end
  
    if mod(i,temp)<0.01
        disp([num2str(100*i/data_size) '% done.'])
    end
    
end

        