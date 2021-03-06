%% Generate Point Clouds for HAR
%==========================================================================
% Authors #1 Simin Zhu
% Authors #3 Chakir
% Authors #2 Mujtaba
% Version 1.0
%==========================================================================
 
%% Extract all the files
Dir = pwd;
%Dir = '/scratch/szhu2/Dataset_848';
rootdir = dir(fullfile(Dir, '/Dataset_848')).folder;
%rootdir = dir(Dir).folder;
myFiles = dir(fullfile(rootdir, '*/*.dat'));
 
%% Loop through all data files in all folders
for k = 1:length(myFiles) 
    %% Extract the data sequence
    path = strcat(myFiles(k).folder, '/', myFiles(k).name);
    
    % Create a new csv file for output (with necessary folders)
    [~, folderName] = fileparts(myFiles(k).folder);
    newFileName = strrep(myFiles(k).name, '.dat', '.csv');
    if not(isfolder(['Point Cloud Dataset/', folderName]))
       mkdir(['Point Cloud Dataset/', folderName]) 
    end
    newFile = fullfile('Point Cloud Dataset', folderName, newFileName);
    %edit(newFile)
    
    fileID = fopen(path, 'r');
    dataArray = textscan(fileID, '%f');
    fclose(fileID);
    radarData = dataArray{1};
    clear fileID dataArray ans;
 
    %% Extract radar parameters
    fc = radarData(1); % Center frequency
    Tsweep = radarData(2)/1000; % Sweep time in sec
    NTS = radarData(3); % Number of time samples per sweep
    Bw = radarData(4); % FMCW Bandwidth. For FSK, it is frequency step;
    Data = radarData(5:end); % raw data in I+j*Q format
    fs = NTS/Tsweep; % sampling frequency ADC
    record_length = length(Data)/NTS*Tsweep; % length of recording in s
    nc = record_length/Tsweep; % number of chirps
 
    %% plot the processing results?
    is_plot = 0;
 
    %% Range-time processing
    Data_range_MTI = RT_Generation(Data,NTS,nc);
    %Time axis
    axis_RT_time = linspace(Tsweep,Tsweep*size(Data_range_MTI,2),size(Data_range_MTI,2))';
    %Range axis
    r_max = (fs*0.5*physconst('LightSpeed'))/(2*Bw/Tsweep);
    axis_RT_range = linspace(0,r_max,size(Data_range_MTI,1));
    %Plot the range profile of the data
    if is_plot == 1
        figure(1);
        colormap(jet);
        imagesc(axis_RT_time,axis_RT_range,20*log10(abs(Data_range_MTI)));
        xlabel('Time (s)');
        ylabel('Range (m)');
        title('Range Profiles');
        clim = get(gca,'CLim'); axis xy;
        set(gca, 'CLim', clim(2)+[-60,0]);
    end
 
    %% Doppler-time processing
    TimeWindowLength = 200;
    [Data_spec_MTI2,idx_r] = Spec_Generation(Data_range_MTI,TimeWindowLength);
    %Time axis
    axis_spec_time = linspace(Tsweep*TimeWindowLength,Tsweep*TimeWindowLength*size(Data_spec_MTI2,2),size(Data_spec_MTI2,2))';
    %Velocity axis
    v_max = (physconst('LightSpeed')/fc)/(4*Tsweep);
    axis_spec_velocity = linspace(-v_max/2,v_max/2,size(Data_spec_MTI2,1));
    % Plot Spectrogram
    if is_plot == 1
        figure(2)
        imagesc(axis_spec_time,axis_spec_velocity,20*log10(Data_spec_MTI2));
        colormap('jet'); axis xy;
        clim = get(gca,'CLim');
        set(gca, 'CLim', clim(2)+[-40,0]);
        xlabel('Time[s]', 'FontSize',16);
        ylabel('Velocity [m/s]','FontSize',16);
        set(gca, 'FontSize',16);
    end
 
    %% CA_CFAR
    CFAR_winv = 100;
    CFAR_winh = 100;
    CFAR_wingv = 25;
    CFAR_wingh = 25;
    pfa = 5e-3;
    CFAR_2D_out_h = CA_CFAR_2D_fast(Data_spec_MTI2,CFAR_winv,CFAR_wingv,1,0,pfa);
    CFAR_2D_out_v = CA_CFAR_2D_fast(Data_spec_MTI2,1,0,CFAR_winh,CFAR_wingh,pfa);
    CFAR_2D_out = CFAR_2D_out_h .* CFAR_2D_out_v;
    Data_spec_MTI2 = 20*log10(Data_spec_MTI2);
    if is_plot == 1
        figure(3)
        imagesc(axis_spec_time,axis_spec_velocity,CFAR_2D_out);
        axis xy;
        xlabel('Time[s]', 'FontSize',16);
        ylabel('Velocity [m/s]','FontSize',16);
    end
 
    %% Save Point Cloud and Labels
    index = 1;
    point_cloud = zeros(4, sum(CFAR_2D_out, 'all'));
    for i = 1:size(CFAR_2D_out, 1)
        for j = 1:size(CFAR_2D_out, 2)
            if (CFAR_2D_out(i, j) == 1)
                time_step = round(axis_spec_time(j)* 1000);
                point_cloud(1, index) = time_step / 1000;
                point_cloud(2, index) = axis_RT_range(:, idx_r(:,time_step));
                point_cloud(3, index) = axis_spec_velocity(:,i);
                point_cloud(4, index) = Data_spec_MTI2(i, j);
                index = index + 1;
            end
        end
    end
    point_cloud = point_cloud';
    writematrix(point_cloud, newFile);
 
    %% Visualizations
    if is_plot == 1
    figure(9)
    pointcloud = pointCloud(point_cloud(:,1:3), point_cloud(:,4));
    pcshow(pointcloud); 
    xlabel('Time[s]', 'FontSize',12);
    ylabel('Range [m]','FontSize',12);
    zlabel('Velocity [m/s]','FontSize',12);    
    end
    
    % Label Generation
    [person,activity,repetition] = Label_extract( path );
    % Create a new label file for output (with necessary folders)
    [~, folderName] = fileparts(myFiles(k).folder);
    newFileName = strrep(myFiles(k).name, '.dat', '.txt');
    if not(isfolder(['Labels/', folderName]))
       mkdir(['Labels/', folderName]) 
    end
    newFile = fullfile('Labels', folderName, newFileName);
    %edit(newFile)
    fileID = fopen(newFile,'w');
    formatSpec = '%d';
    fprintf(fileID,formatSpec,str2double(activity));
    fclose(fileID);
 
end
 
 


