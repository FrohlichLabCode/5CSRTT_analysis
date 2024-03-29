%% prepare directory
clear all
clc

cluster = 0;
skipRec = 0;
animalCodes = {'0171','0180','0181','0179'};
analysisType = 'SpkPLV';
folderSuffix = '';%'_validChns_new';
doPlot = 1;
doMix = 0; %<<<
level = '7b';%<<<
alignID = 2; %1=Init, 2=Stim, 3=Touch, 4=Opto
hitMissID = 1; %1=Correct, 2=Premature, 3=Incorrect, 4=Omission, 5=noPremature
if doMix == 1
    mixSuffix = '_mix';
    folderLevel = '6bc';
else
    mixSuffix = [];
    folderLevel = level;
end

BaseDir = ['E:/Dropbox (Frohlich Lab)/Angel/FerretData/'];

for iAnimal = 1%:numel(animalCodes)
    animalCode = animalCodes{iAnimal};
    if strcmp(animalCode, '0171')
        folderSuffix = '_firstChn';%'_validChns_new';
    else
        folderSuffix = '_optoChn';%'_validChns_new';
    end
    if strcmp(animalCode, '0179')
        if level(2)=='b';level(2)='a';end
        if level(2)=='c';level(2)='d';end
        folderLevel = level;
    end
    addpath(genpath('E:/Dropbox (Frohlich Lab)/Frohlich Lab Team Folder/Codebase/CodeAngel/Ephys/'));
    PreprocessDir = [BaseDir animalCode '/Preprocessed' mixSuffix '/'];
    AnalysisDir   = [BaseDir animalCode '/Analyzed/'];
    GroupAnalysisDir = [BaseDir animalCode '/GroupAnalysis/SpkPLV' folderSuffix '_' folderLevel '/'];
%     fileInfo   = dir([PreprocessDir animalCode '_Level' level '_*']); % detect files to load/convert  '_LateralVideo*' can't process opto
%     numRec = numel(fileInfo);
    
    % get region info
    region = getAnimalInfo(animalCode);
    regionNames = region.Names;
    numRegion = numel(regionNames);
    
    [alignNames, delayNames, delayTypes, hitMissNames, optoNames] = getCSRTTInfo(level);
    alignName = alignNames{alignID}; %Stim
    hitMissName = hitMissNames{hitMissID}(1:3); %Cor
    alignHitName = ['_' alignName hitMissName]; %StimCor        
    if level(1) == '6'
        condNames = delayNames;
        condID = [2,3];
    elseif level(1) == '7'
        condNames = optoNames;
        condID = [1,2,5];
    end
    %twin = [-3,0]; % last 3s of delay
    numCond = numel(condID);

    
    if exist([GroupAnalysisDir '/CondContrast/SpkPLV_Cond-Sham_20spk_' level '.mat']) && skipRec == 1
        load([GroupAnalysisDir '/CondContrast/SpkPLV_Cond-Sham_20spk_' level '.mat']);
        [numRec, numRegionSpk, numRegionLFP, numFreq, numBins] = size(SpkPLVMnchn.Sham);

    else
        if level(1) == '7'
            shamName = ['SpkPLV_StimCorSham_20spk_' level];
        elseif level(1) == '6'
            shamName = ['SpkPLV_StimCorD4_20spk_' level];
        end
        load([GroupAnalysisDir shamName '.mat'], 'allSpkPLVMnchn','dat');
        [numRec, numRegionSpk, numRegionLFP, numFreq, numBins] = size(allSpkPLVMnchn);
        dimension = size(allSpkPLVMnchn);
        SpkPLVMnchn.Sham = allSpkPLVMnchn;
        SpkPLVMnchnMnses.Sham = reshape(nanmean(allSpkPLVMnchn,1),dimension(2:end));
        clear allSpkPLVMnchn
        for iCond = 1:numCond
            condName = condNames{condID(iCond)};
            fileName = ['SpkPLV_StimCor' condName '_20spk_' level];
            load([GroupAnalysisDir fileName '.mat'], 'allSpkPLVMnchn','dat');          
            SpkPLVMnchn.(condName) = allSpkPLVMnchn;
            SpkPLVMnchnMnses.(condName) = reshape(nanmean(allSpkPLVMnchn,1),dimension(2:end));
            minNrec = min(size(SpkPLVMnchn.(condName),1), size(SpkPLVMnchn.Sham,1));
            ContrastPLVMnchn.(condName) = SpkPLVMnchn.(condName)(1:minNrec,:,:,:,:) - SpkPLVMnchn.Sham(1:minNrec,:,:,:,:); %make sure same dimension
            ContrastPLVMnchnMnses.(condName) = SpkPLVMnchnMnses.(condName) - SpkPLVMnchnMnses.Sham;
        end
        AH_mkdir([GroupAnalysisDir '/CondContrast/']);
        tvec = linspace(dat.twin(1),dat.twin(2),dat.numBins);
        save([GroupAnalysisDir '/CondContrast/SpkPLV_Cond-Sham_20spk_' level],'SpkPLVMnchn','SpkPLVMnchnMnses','ContrastPLVMnchn','ContrastPLVMnchnMnses','dat','tvec') ;
    end
    
    
    %% plot
    [foi, tickLoc, tickLabel,~,~] = getFoiLabel(2, 128, 150, 2);% lowFreq, highFreq, numFreqs, linORlog)
    twin = [-3,0]; % last 3s of delay
    tMask = tvec>=twin(1) & tvec<=twin(2);
    numRow = numRegionSpk;
    numCol = numRegionLFP;
    saveDir = [GroupAnalysisDir 'CondContrast/'];
    for iCond = 1:numCond-1
        condName = condNames{condID(iCond)};
        fig1 = AH_figure(numRow, numCol, ['SpkPLV_' condName '-Sham']); %numRows, numCols, name
        fig3 = AH_figure(numRow, numCol, ['SpkPLV3s_' condName '-Sham']); %numRows, numCols, name
        for iRegionSpk = 1:numRegionSpk
            regionNameSpk = regionNames{iRegionSpk};
            for iRegionLFP = 1:numRegionLFP
                regionNameLFP = regionNames{iRegionLFP};
                                
                set(0,'CurrentFigure',fig1)                
                subplot(numRow, numCol, (iRegionSpk-1)*numCol+iRegionLFP)
                hold on
                
                toPlot = squeeze(ContrastPLVMnchnMnses.(condName)(iRegionSpk,iRegionLFP,:,:)); %average across spike channels (2nd last dimension)
                figName1 = ['SpkPLV_' condName '-Sham_20spk_' level];

                imagesc(tvec,1:numFreq, toPlot)
                title([regionNameSpk '-' regionNameLFP ' SpkPLV'])
                xlabel('Time to stim [s]');
                ylabel('Freq [Hz]');      
                axis tight
                set(gca,'YDir','normal','TickDir','out','YTick',tickLoc,'YTickLabel',tickLabel)%
                %vline(0,'k');vline(-5,'r');
                cl = colorbar('northoutside'); %ylabel(cl, 'Spike-PLV');
                AH_rwb() %use rwbmap
                if strcmp(animalCode,'0180') || strcmp(animalCode,'0171')
                    if iRegionSpk == 2 % LPl drive;
                        caxis([-0.2,0.2])
                    elseif iRegionSpk == 3; caxis([-0.05,0.05])
                    else; caxis([-0.05,0.05])
                    end
                else
                    if iRegionSpk == 2 % LPl drive;
                        caxis([-0.02,0.02])
                    elseif iRegionSpk == 3; caxis([-0.005,0.005])
                    else; caxis([-0.005,0.005])
                    end
                end
                %%
                set(0,'CurrentFigure',fig3)
                subplot(numRow, numCol, (iRegionSpk-1)*numCol+iRegionLFP)
                hold on
                toPlot = squeeze(nanmean(ContrastPLVMnchn.(condName)(:,iRegionSpk,iRegionLFP,:,tMask),5)); %average across spike channels (2nd last dimension)
                figName3 = ['SpkPLV_' condName '-Sham_Mn3s_20spk_' level];
                
                sem = nanstd(toPlot, [], 1)/sqrt(size(toPlot,1));
                shadedErrorBar(1:numFreq, nanmean(toPlot,1),sem, '-k',0.5)
                set(gca,'TickDir','out','XTick',tickLoc,'XTickLabel',tickLabel)
                set(gcf,'renderer','Painters')
                title([regionNameSpk '-' regionNameLFP ' SpkPLV Mn3s']);
                if iRegionSpk == numRegion; xlabel('Freq [Hz]'); end
                if iRegionLFP == 1; ylabel('PLV'); end
            end
        end
        savefig(fig1, [saveDir figName1 '.fig'],'compact');
        saveas(fig1, [saveDir figName1 '.png']);
        savefig(fig3, [saveDir figName3 '.fig'],'compact');
        saveas(fig3, [saveDir figName3 '.png']); 
    end
end
