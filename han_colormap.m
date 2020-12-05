function map = han_colormap(m)
%HAN_COLORMAP returns a M-by-3 matrix containing my favorite colors.
%   Mostly I use this to keep the color of identified units in my tetrode
%   object and other in-vivo ephys related scripts the same. If you feel
%   artsy, you should totally change this

%   han_colormap is part of Bearphys, Bearphys is made by Johannes de Jong,
%   j.w.dejong@berkeley.edu.


% How bit do we want the map
if nargin < 1
   f = get(groot,'CurrentFigure');
   if isempty(f)
      m = size(get(groot,'DefaultFigureColormap'),1);
   else
      m = size(f.Colormap,1);
   end
end

% The default colors
default = zeros(10,3);
default(1,:) = [224, 224, 224]; % Unclustered is light gray
default(2,:) = [0, 192, 0]; % Unit 1 is green
default(3,:) = [255, 0, 0]; % Unit 2 is red
default(4,:) = [0, 32, 255]; % Unit 3 is blue
default(5,:) = [255, 160, 16]; % Unit 4 is orange (because it's the BEST unit)
default(6,:) = [160, 32, 255]; % Unit 5 is purple
default(7,:) = [249, 228, 183]; % Unit 6 is not a unit but a BEIGEIST
default(8,:) = [80, 208, 255]; % Unit 7 light blue
default(9,:) = [255, 224, 32]; % Unit 8 is yellow
default(10,:) = [63, 224, 208]; % Unit 9 is Turquoise

% 1-0 max-min
default = default./255;

% Fill our the map
map = zeros(m, 3);
i=0;
while i<m
    map(i+1,:) = default(mod(i,10)+1, :);
    i = i+1;
end


end

