
% Scripts neccessary for this code to function as needed
% 
% AH_mkdir.m %              (a)
% getAnimalInfo.m %         (a)
% getRegionPairName.m       (a)  <- Function called within getAnimalInfo
% vline.m %                 (a)
% is_PSTHstats.m %          (b)
% is_load.m %               (b)
%  
% These scripts can be found on:
% (a) https://www.dropbox.com/home/Frohlich%20Lab%20Team%20Folder/Codebase/CodeAngel/Ephys/AH_toolbox
% (b) https://www.dropbox.com/home/Frohlich%20Lab%20Team%20Folder/Codebase/CodeAngel/Ephys
%
% Created by Angel Huang 2019.8
% Validated by William Stanford 2019.9

clear

addpath(genpath('E:\Dropbox (Frohlich Lab)\Frohlich Lab Team Folder\Codebase\CodeAngel\Ephys\'));
skipRec = 1;
%cluster = 0;
level = '6'; % 6 or 7
if level(1) == '7';opto=1;end 
animalCodes = {'0180','0181','0179','0171'}; % 0171 0173 need to use CSRTT_PSTH
BaseDir = ['E:/Dropbox (Frohlich Lab)/Angel/FerretData/'];
doCleanSpk = 1;
eeglabPreproc = 1; % if use variables coming from EEGLAB preprocessing pipeline

% Set up directories
BaseDir = ['E:/Dropbox (Frohlich Lab)/Angel/FerretData/'];
for iAnimal = 1:numel(animalCodes)
    animalCode = animalCodes{iAnimal};
    
    PreprocessDir = [BaseDir animalCode '/Preprocessed/'];
    AnalysisDir   = [BaseDir animalCode '/Analyzed/'];
    %BehavDatDir   = ['E:/FerretData/' animalCode '/behav/'];
    fileInfo   = dir([PreprocessDir animalCode '_Level' level '*']); % detect files to load/convert  '_LateralVideo*'    

% loop through each recording
for irec = 1:numel(fileInfo)
    recName = fileInfo(irec).name; % Store current record name
    splitName   = strsplit(recName,'_'); % Split by _, used to find level later
    %if cluster ==0 && datetime(splitName{4}, 'InputFormat', 'yyyyMMdd') <= datetime('20190110', 'InputFormat', 'yyyyMMdd'); continue;end

    % Set up directories for each record, for preprocessed data and to store final figures
    rootPreprocessDir = [PreprocessDir recName '/'];
    if doCleanSpk == 1
        rootAnalysisDir   = [AnalysisDir recName '/PSTHcc_StimCor/'];
    else
        rootAnalysisDir   = [AnalysisDir recName '/PSTH_StimCor/'];
    end
    fprintf('Analyzing record %s \n',recName); 

    if exist(join(rootAnalysisDir),'dir') % skip already analyzed records
        fprintf('Record %s already analyzed \n',recName'); 
        if skipRec == 1; continue; end; end
    
    % load preprocessed event data for correct trials
    % Varies dependending on with/without stimulation
    if isempty(level); level = splitName{2}(6);end    
    if level(1) == '6'
        if exist([rootPreprocessDir 'eventTimes_StimCor.mat'])
            load([rootPreprocessDir 'eventTimes_StimCor.mat']);            
        end
        condIDs = [1,2,3];
    elseif level(1) == '7'
        if exist([rootPreprocessDir 'optoEventTimes_StimCor.mat'])
            load([rootPreprocessDir 'optoEventTimes_StimCor.mat']);
        else
            load([rootPreprocessDir 'optoEventTimes_all_Correct.mat']);
        end
        condIDs = [1,2,5]; %theta, alpha, sham
    end

    numCond = numel(condIDs);
    region = getAnimalInfo(animalCode);
    regionNames = region.Names;
    numRegion = numel(regionNames);

    
    % region info
    if eeglabPreproc == 1
        lfp = is_load([rootPreprocessDir 'eeglab_validChn.mat'], 'lfp');
    else
        % Currently unused (for old preprocessing pipeline)
        [lfp.validChn,~] = keepChn(recName);
    
        %already loaded: eventNames = {'Init','StimOnset','Touch','OptoOnset'};
        if opto == 0
            eventID = [2];
        else
            eventID = [2];
        end
        numEvents  = numel(eventID);
    end
    %%

validChn = lfp.validChn;
files = dir([rootPreprocessDir 'spikes/spk*.mat']);
totalNumChn = length(files); % get total number of channels before exclusion

% declare info about analysis window and binning of PSTH
%twin = [-2 2]; % window to analyze (in s)
binSize = 0.02;  % in seconds (for fine detail use .02=20ms, but may have more noisy fluctuation)

%% preprocess session behav data
%%
condCount = 1;

for iCond = 1:numel(condIDs) % for each condition
    condID = condIDs(iCond);
    condName = condNames{condID};
    if level(1) == '6'
        baseTwin = [-2,0] - str2num(condName(2)); %2sec before stimOn
    elseif level(1) == '7'
        baseTwin = [-8,-6]; % for opto conditions, collapse all delay durations
    end
    twin = twins{condID};
    evtTime = evtTimes{condID};% only get opto onset
    
    % Compute baseline-z-scored PSTH for each channel
    display(['computing PSTH ' recName ' condition: StimCor' condName]);
    for iChn = 1:totalNumChn
        if doCleanSpk == 1
            load([rootPreprocessDir 'spikes/cleanSpk_' num2str(iChn)]);
        else
        	load([rootPreprocessDir 'spikes/spk_' num2str(iChn)]); 
        end
        spks  = spkTime; % spike times in seconds % OLD: ./1000; % convert spike times (ms) to seconds
        [timePSTH,PSTHrate,psthstats,psthTrial] = is_PSTHstats(evtTime,spks,twin,binSize); % CZ: PSTHrate's 1st timept is time of saccade
        
        PSTH(condCount,iChn,:)  = PSTHrate;
        % normalise to pre saccade firing rate
        preBins = (timePSTH>=baseTwin(1) & timePSTH<baseTwin(2)); % 50ms before saccade
        frMean  = nanmedian(PSTHrate(preBins));
        frSTD   = nanstd(PSTHrate(preBins));
        frZ(condCount,iChn,:) = (PSTHrate-frMean)/frSTD; % Spike z score
        %spkCell{condCount,iChn} = spks; % save spike times in s for later
    end
    
    numBins = numel(timePSTH);
    
    condCount = condCount + 1;
    
end

%% 
data2Analyze = frZ;
numDivX = 5;

ipanel = 1;

screensize = get( groot, 'Screensize' );
fig = figure('Position',[10 50 (screensize(3)-100)/2 (screensize(4)-150)/4*numCond]);
for iCond = 1:numCond
    condID = condIDs(iCond);
    condName = condNames{condID};
    for iRegion = 1:numel(regionNames)
        regionName = regionNames{iRegion};
        toPlot = squeeze(data2Analyze(iCond,validChn{iRegion},:));
        
        subplot(numCond,numel(regionNames),ipanel)
        
        imagesc(toPlot) % Display data with scaled color
        title(['Z-score FR PSTH: ' regionName '; ' condName])
        xlabel('Time [s]');
        ylabel('Channel');
        set(gca,'XTick',linspace(1,numBins,numDivX))
        set(gca,'XTickLabel',linspace(twin(1),twin(2),numDivX))
        h = colorbar;
        ylabel(h, 'Z-score FR')
        caxis([-0.5 6])
        axis tight
        
        ipanel = ipanel + 1;
    end
    
end
AH_mkdir(rootAnalysisDir);
savefig(fig, [rootAnalysisDir 'Z-score FR PSTH_-2~0base.fig'],'compact');
saveas(fig, [rootAnalysisDir 'Z-score FR PSTH_-2~0base.png']);

clear toPlot
%% chn avged
% Dynamically adjust figure size according to screensize
screensize = get( groot, 'Screensize' );
fig = figure('Position',[10 50 (screensize(3)-100)/2 (screensize(4)-150)/4]);
tvec = linspace(twin(1), twin(2), size(frZ,length(size(frZ))));

for iRegion = 1:numel(regionNames)
    subplot(1,numel(regionNames),iRegion)
    hold on
    legendName = {};
    if length(condIDs) == 1
        sliceData = reshape(data2Analyze(condIDs(1),validChn{iRegion},:),...
            [numel(validChn{iRegion}),size(data2Analyze,3)]);
        sliceData(isinf(sliceData)) = NaN; % replace Inf with NaN
        data2Average = sliceData(any(sliceData,2),:); % remove channels without any spike from mean calculation
        toPlot(iCond,iRegion,:) = squeeze(nanmean(data2Average,1));
        toPlot(iCond,iRegion,:) = smoothts(toPlot(iCond,iRegion,:),'g',3,0.65);
        pl = plot(toPlot, 'LineWidth', 1.5);
        vline(0);
        legendName{end+1} = condNames{condID(1)};
    else
        for iCond = flip(1:numCond)
            condID = condIDs(iCond);
            condName = condNames{condID};
            % delete all channels with all zeros
            sliceData = reshape(data2Analyze(iCond,validChn{iRegion},:),[numel(validChn{iRegion}),size(data2Analyze,3)]);
            sliceData(isinf(sliceData)) = NaN; % replace Inf with NaN
            data2Average = sliceData(any(sliceData,2),:); % remove channels without any spike
            toPlot(iCond,iRegion,:) = squeeze(nanmean(data2Average,1)); % average across channels
            toPlot(iCond,iRegion,:) = smoothts(toPlot(iCond,iRegion,:),'g',3,0.65);
            pl = plot(tvec, squeeze(toPlot(iCond,iRegion,:)), 'LineWidth', 1.5);
            pl.Color(4) = 0.4; % transparent
            legendName{end+1} = condName;
            vline(0);

        end
    end
    if iRegion == 1; legend(legendName); end % NOTE: match plotting order
    title(['Z-score FR PSTH: ' regionNames{iRegion} ])
    xlabel('Time [s]');
    ylabel('Z-score Firing Rate [Hz]');
%     set(gca,'XTick',linspace(1,numBins,numDivX))
%     set(gca,'XTickLabel',linspace(twin(1),twin(2),numDivX))    
    
    axis tight
    vline(0,'k--');
    ylim([-2 4])
end
AH_mkdir(rootAnalysisDir);
save([rootAnalysisDir 'zPSTH_mean.mat'],'timePSTH','toPlot','frZ','validChn', '-v7.3');
fileName = ['Z-score FR PSTH_chn-avg_bin' num2str(binSize) '_-2~0base'];
savefig(fig, [rootAnalysisDir fileName '.fig'],'compact');
saveas(fig, [rootAnalysisDir fileName '.png']);
close all % close all figures
end % end of irec
end % end of iAnimal