%% Start
TTL = 2;
interval = [4.5 , 5.5]*10^3;
included_trials = 'all';
%included_trials = [1, 200];
space = 'height';
nr_PCs = 3;




%% Sort all waveforms into out or inside the interval
tagged_selector = false(size(Tetrode.timestamps));
stamps = Tetrode.TTL(TTL).on;

if strcmp(included_trials, 'all')
    included_trials = [1, length(stamps)];
end

for i=included_trials(1):included_trials(2)
    selector = Tetrode.timestamps>=stamps(i)+interval(1) & Tetrode.timestamps<=stamps(i)+interval(2);
    tagged_selector(selector) = true;
end
numbers = [1:length(Tetrode.timestamps)];
tagged = numbers(tagged_selector);


%% Pick an equal number of randomly distributed waveforms
non_tagged = numbers(~tagged_selector);
non_tagged = randsample(non_tagged, length(tagged));


%% We'll do this analysis on the full_PCA or some other atribute
if strcmp(space,'pca')
    [~, X, explained, fig] = Tetrode.full_pca();
    close all
    X = X(:,1:nr_PCs);
else
    X=[];
   for i=1:4
       if Tetrode.settings.working_electrodes(i)
           X = [X, Tetrode.attributes(i).(space)'];
       end
   end
end

% Make sure we have at least 3 dimensions to work with
if size(X, 2)<3
    X = [X, ones(size(X(:,1)))];
end

%% Display the tagged waveform
figure()
scatter3(X(:,1), X(:,2), X(:,3),'.','SizeData',1);
hold on
scatter3(X(tagged,1), X(tagged,2), X(tagged, 3),'o')
xlabel('X1'); ylabel('X2'); zlabel('X3');

%% Calculate the std in all dimensions
temp = X(tagged,:);
temp_mean = repmat(mean(temp),size(temp,1),1); % Subtract mean
temp = sum((temp-temp_mean).^2,2); % Pytagoras, but no sqrt
sigma_tagged = sqrt(sum(temp)/(size(temp,1)-1));

temp = X(non_tagged,:);
temp_mean = repmat(mean(temp),size(temp,1),1); % Subtract mean
temp = sum((temp-temp_mean).^2,2); % Pytagoras, but no sqrt
sigma_non_tagged = sqrt(sum(temp)/(size(temp,1)-1));


%% For every other waveform, calculate the distance to these waveforms
distances = zeros(length(Tetrode.cells), 1);
delta_tagged_gaus = distances;
delta_all_gaus = distances;

% Nr of features
nr_f = size(X,2);

start_time = tic;
for i=1:length(Tetrode.cells)
    % Calculate the distance to every tagged waveform
    delta_tagged = zeros(length(tagged), 1);
    for j=1:length(tagged)
        temp = 0;
        for k=1:nr_f
            temp = temp + (X(tagged(j), k)-X(i,k))^2;
        end
        delta_tagged(j) = sqrt(temp);
    end
    % Apply Gaussian to distances to tagged waveforms
    temp = exp(-0.5*(delta_tagged/sigma_tagged).^2);
    delta_tagged_gaus(i) = mean((1/(sigma_tagged*sqrt(2*pi)))*temp);
    
    %delta_tagged_gaus(i) = sum(exp(-1 * delta_tagged.^2/(2*sigma_tagged^2)));
    
    delta_all = zeros(length(non_tagged),1);
    for j=1:length(non_tagged)
        temp = 0;
        for k=1:nr_f
            temp = temp + (X(non_tagged(j), k)-X(i,k))^2; 
        end
        delta_all(j) = sqrt(temp);
    end
    
    % Apply Gaussian to all
    temp = exp(-0.5*(delta_all/sigma_non_tagged).^2);
    delta_all_gaus(i) = mean((1/(sigma_non_tagged*sqrt(2*pi)))*temp);
    
    %delta_all_gaus(i) = sum(exp(-1 * delta_all.^2/(2*sigma_non_tagged^2)));
    
    % Update progres
    fraction_done = i/length(Tetrode.cells);
    if mod(i,10000)==0
        time_elapsed =toc(start_time);
        total_expected = time_elapsed/fraction_done;
        time_untill_done = (1-fraction_done)*total_expected;
        
        disp(['Fraction done: ' num2str(fraction_done*100) '% time elapsed: ' num2str(time_elapsed) ' expected: ' num2str(total_expected) ' untill done: ' num2str(time_untill_done)]);
    end
    
end
distances = delta_tagged_gaus./delta_all_gaus;

%% Completely arbitrarliy remove outliers
max_value = max(distances(tagged));
distances(distances>max_value)=max_value;


%% Make some figures
figure()
histogram(delta_tagged_gaus,'DisplayName','Tagged waveforms')
hold on
histogram(delta_all_gaus,'DisplayName','All waveforms')
ylabel('count #'); xlabel('Distance from tagged/non tagged')
legend();
figure()
histogram(distances);
ylabel('count #'); xlabel('P-tagged/P-all');

%% Plot all the waveforms
figure()
scatter3(X(:,1), X(:,2), X(:,3),'.', 'CData',distances)
h=colorbar; ylabel(h, 'p-tagged/p-all')
title(space)

