function [TruthSet,ROCtbl]=AnalyseAvatarTracks(truthtable,avatartracks,avatarpath)
%% Plots a ROC and cost curves given simulations using Avatar
 
    
    [ TruthSet.classification,TruthSet.TrackingTime,TruthSet.ROC]=getPerformance( truthtable ); %get performance
     
    stats=getCost(truthtable); %get cost only run for the truth table
    TruthSet.stats=stats;
%     oldir=cd;
%     cd(tempdir);
    
    
    % Get the Avatar simulation data
%     [FileName,PathName,~] = uigetfile('*.mat','Get Avatar Tables','MultiSelect','on');
%     cd(oldir);
    FileName=avatartracks;
    PathName=avatarpath;
    h=waitbar(0,'Analysing Avatar Simulations');
    r_2=zeros(size(FileName));
    SearchRadius=zeros(size(FileName));
    CellRadius=zeros(size(FileName));
    CellMemory=zeros(size(FileName));
    LostTime=zeros(size(FileName));
    PauseTime=zeros(size(FileName));
    GoTime=zeros(size(FileName));
    NumberOfSteps=zeros(size(FileName));
    condition=1;
    for i=1:length(FileName)
        load([PathName FileName{i}]); %load the avatar trackfile
        ndx(1)=regexp(FileName{i},'_r_')+3;
        ndx(2)=regexp(FileName{i},'_sr')-1;
        r_2(i)=str2num(FileName{i}(ndx(1):ndx(2)));
        ndx(1)=regexp(FileName{i},'_sr_')+4;
        ndx(2)=regexp(FileName{i},'_cr')-1;
        SearchRadius(i)=str2num(FileName{i}(ndx(1):ndx(2)));
        if ~isempty(regexp(FileName{i},'_cr_'))&&isempty(regexp(FileName{i},'_mem_'))
        ndx(1)=regexp(FileName{i},'_cr_')+4;
        ndx(2)=regexp(FileName{i},'.mat')-1;
        CellRadius(i)=str2num(FileName{i}(ndx(1):ndx(2))); 
        elseif ~isempty(regexp(FileName{i},'_mem_'))
        ndx(1)=regexp(FileName{i},'_cr_')+4;
        ndx(2)=regexp(FileName{i},'_mem_')-1;
        CellRadius(i)=str2num(FileName{i}(ndx(1):ndx(2))); 
        ndx(1)=regexp(FileName{i},'_mem_')+5;
        ndx(2)=regexp(FileName{i},'.mat')-1;
        CellMemory(i)=str2num(FileName{i}(ndx(1):ndx(2))); 
        end
        
        
        [ classification(i),~,ROC(i),condition ] = GetAvatarPerformance( tbl,TruthSet,condition ); %get performance of avatar for given tracking parameters
        % simulate time taken by a typical user
        GoTime(i)=sum(classification(i).go(:))*stats.median.go; % median not that sensitive to outliers.
        LostTime(i)=sum(classification(i).lost(:))*stats.median.lost;
        PauseTime(i)=sum(classification(i).pause(:))*stats.median.pause;
        NumberOfSteps(i)=sum(classification(i).go(:)|classification(i).lost(:)|classification(i).pause(:));
        waitbar(i/length(FileName),h);
    end
    close(h);
    
   
    TP=[ROC(:).TP];
    FP=[ROC(:).FP];
    TN=[ROC(:).TN];
    FN=[ROC(:).FN];
    TotalOutcomes=TP+FP+TN+FN;
    FPR=[ROC(:).FPR];
    TPR=[ROC(:).TPR];
    PPV=TP./(TP+FP);
    TotalNegatives=[ROC(:).TotalNegatives];
    TotalPositives=[ROC(:).TotalPositives];
    ROCtbl=table(r_2',SearchRadius',CellRadius',CellMemory',FPR',TPR',PPV',GoTime',LostTime',PauseTime',NumberOfSteps',TotalNegatives',TotalPositives',...
        TP',FP',TN',FN',TotalOutcomes','VariableNames',{'Rho' 'SearchRadius' 'CellRadius' 'CellMemory' 'FPR'...
        'TPR' 'PPV' 'GoTime' 'LostTime' 'PauseTime' 'NumberOfSteps' 'TotalNegatives' 'TotalPositives' 'TruePositives' 'FalsePositives' 'TrueNegatives'...
        'FalseNegatives' 'TotalOutcomes'});
    
    % find parameter that is varied
    str={'Rho','SearchRadius','CellRadius','CellMemory'};
    ndx=max([var(r_2),var(SearchRadius),var(CellRadius),var(CellMemory)])==[var(r_2),var(SearchRadius),var(CellRadius),var(CellMemory)]; %whichever parameter varies
    Parameter=str{ndx};
    ROCtbl=sortrows(ROCtbl,Parameter);
        %plotting ROC curve
    figure('Name','Avatar ROC curve');
    stairs((ROCtbl.FPR),ROCtbl.TPR);
    if strcmp(Parameter,'Rho')
       title(['SR:' num2str(ROCtbl.SearchRadius(1))]); 
    end
    hold on;
    switch(Parameter)
        case 'Rho'
            scatter(ROCtbl.FPR,ROCtbl.TPR,20,ROCtbl.Rho,'filled','MarkerEdgeColor','k');
                text(ROCtbl.FPR,ROCtbl.TPR,arrayfun(@(x) {x},ROCtbl.Rho),'FontSize',8);
        case 'SearchRadius'
            scatter(ROCtbl.FPR,ROCtbl.TPR,20,ROCtbl.SearchRadius,'filled','MarkerEdgeColor','k');
        case 'CellRadius'
            scatter(ROCtbl.FPR,ROCtbl.TPR,20,ROCtbl.CellRadius,'filled','MarkerEdgeColor','k');
        case 'CellMemory'
            scatter(ROCtbl.FPR,ROCtbl.TPR,20,ROCtbl.CellMemory,'filled','MarkerEdgeColor','k');            
        otherwise
            error('Parameter not recognised');
    end
    colormap('hot');
    h=colorbar;
    h.Label.String=Parameter;
    xlabel('FPR (1-Specificity)');
    ylabel('TPR (Sensitivity)');
    hold off;
    savefig(gcf,[PathName(1:strfind(PathName,'\AvatarTracks')) 'ROC']);
   
    %% Plot ROC curve with cost
    figure('Name','Avatar ROC with Cost');
    stairs(ROCtbl.FPR,ROCtbl.TPR);
    hold on;
    TotalTime=ROCtbl.GoTime+ROCtbl.PauseTime+ROCtbl.LostTime;
    StepTime=TotalTime./ROCtbl.NumberOfSteps;
    scatter(ROCtbl.FPR,ROCtbl.TPR,20,StepTime,'filled','MarkerEdgeColor','k');
    colormap('hot');
    h=colorbar;
    h.Label.String='Step time (seconds)';
    xlabel('FPR (1-Specificity)');
    ylabel('TPR (Sensitivity)');
    hold off;
    
    %% Plot PPV (if vary search radius)
    if strcmp(Parameter,'SearchRadius')
        figure('Name','Avatar simulation of search radius versus PPV');
        plot(ROCtbl.SearchRadius,ROCtbl.PPV,'k-o');
        xlabel('Search radius');
        ylabel('Positive Predictive Value (PPV)');
        ylim([0,1]);
        
        savefig(gcf,[PathName(1:strfind(PathName,'\AvatarTracks')) 'PPV.fig']);
    end
    
    %% Plot parameter versus Cost
    figure('Name','Parameter versus Cost');
    x=ROCtbl.(Parameter);
    y=[ROCtbl.GoTime ROCtbl.LostTime ROCtbl.PauseTime];
    y=y./repmat(ROCtbl.NumberOfSteps,1,3);
    barh(y,'stacked');
    xstr=arrayfun(@(x) num2str(x),x,'UniformOutput',false);
    set(gca,'YTick',1:length(x));
    set(gca,'YTickLabel',xstr);
    legend({'Auto' 'Lost' 'Pause'},'Location','southeast');
    ylabel(Parameter);
    xlabel('Step time (seconds)');
    title('Cost');
    savefig(gcf,[PathName(1:strfind(PathName,'\AvatarTracks')) 'Parameter vs Cost.fig']);
end



function [ classification,TrackingTime,ROC ] = getPerformance( tbl )
% finds the false positive and true positive rates of the tracked data held
% in tracker state

    [r,c]=size(tbl.Tracker_State);
% find true positives    
    TP=cellfun(@(x) strfind(x,'go'),tbl.Tracker_State,...
        'UniformOutput',false);
    TP=cellfun(@(x) ~isempty(x) ,TP);
    classification.go=TP;
    MidTrackNdx=false(r,c);
    for i=1:r
        ndx=tbl.Image_Number{i};
        if length(ndx)>2
            ndx=ndx(2:end-1);
            MidTrackNdx(i,ndx)=1;
        end
    end
   
    classification.lost=cellfun(@(x) strfind(x,'Lost Cell'),tbl.Tracker_State,...
        'UniformOutput',false);
    classification.lost=cellfun(@(x) ~isempty(x),classification.lost);
    classification.pause=cellfun(@(x) strfind(x,'pause'),tbl.Tracker_State,...
        'UniformOutput',false);
    classification.pause=cellfun(@(x) ~isempty(x),classification.pause);
    FN=classification.lost|classification.pause;
    FN=FN&MidTrackNdx;
    TP=classification.go;
    TP=TP&MidTrackNdx;
    
% find true negatives
    TN=cellfun(@(x) strfind(x,'Lost Cell'),tbl.Tracker_State,...
        'UniformOutput',false);
    TN=cellfun(@(x) ~isempty(x),TN);
    EndTrackNdx=false(r,c);
    for i=1:r
        ndx=tbl.Image_Number{i};
        ndx=ndx(end);
        if iscell(tbl.Annotation_Symbol{i})
            AnnotationSymbol=tbl.Annotation_Symbol{i}{end};
            if (ndx~=c)&&(~strcmp(AnnotationSymbol,'NC'))
                EndTrackNdx(i,ndx)=1;
            end
        end
    end
    TN=TN&EndTrackNdx;
    
% find false positives
    FP=(classification.go);
        FP=FP&EndTrackNdx;
    classification.TP=TP;
    classification.TN=TN;
    classification.FP=FP;
    classification.FN=FN;
    
    %get tracking time
    TrackingTime=NaN(r,c);
    for i=1:r
        ndx=tbl.Image_Number{i};
        TT=tbl.Tracking_Time{i};
        TT=TT(2:end)-TT(1:end-1);
        TT=TT*24*60*60;
        TrackingTime(i,ndx(1:end-1))=TT;
    end
    
    x=classification.TP+classification.FN;
    ROC.TotalPositives=sum(x(:));
    x=classification.TN+classification.FP;
    ROC.TotalNegatives=sum(x(:));
    ROC.TP=sum(classification.TP(:));
    ROC.FP=sum(classification.FP(:));
    ROC.TN=sum(classification.TN(:));
    ROC.FN=sum(classification.FN(:));
    ROC.TPR=sum(classification.TP(:))/ROC.TotalPositives;
    ROC.FPR=sum(classification.FP(:))/ROC.TotalNegatives;
        

end


function [ classification,TrackingTime,ROC, condition ]=GetAvatarPerformance(tbl, TruthSet,condition)
    
    [r,c]=size(tbl.Tracker_State);

    %truthset outcomes
    truthset.go=TruthSet.classification.go(1:r,:);
    truthset.lost=TruthSet.classification.lost(1:r,:);
    truthset.pause=TruthSet.classification.pause(1:r,:);
    
    %avatar outcomes
    classification.go=cellfun(@(x) strfind(x,'go'),tbl.Tracker_State,...
        'UniformOutput',false);
    classification.go=cellfun(@(x) ~isempty(x) ,classification.go);
    classification.lost=cellfun(@(x) strfind(x,'Lost Cell'),tbl.Tracker_State,...
        'UniformOutput',false);
    classification.lost=cellfun(@(x) ~isempty(x),classification.lost);
    classification.pause=cellfun(@(x) strfind(x,'pause'),tbl.Tracker_State,...
        'UniformOutput',false);
    classification.pause=cellfun(@(x) ~isempty(x),classification.pause);
   
    
    %index for middle track points
    MidTrackNdx=false(r,c);
    for i=1:r
        ndx=tbl.Image_Number{i};
        if length(ndx)>2
            ndx=ndx(2:end-1);
            MidTrackNdx(i,ndx)=1;
        end
    end
    
    %index for initial and final track points
    EndTrackNdx=false(r,c);
    for i=1:r
        ndx=tbl.Image_Number{i};
        ndx=ndx(end);
        if iscell(tbl.Annotation_Symbol{i})
            AnnotationSymbol=tbl.Annotation_Symbol{i}{end};
            if (ndx~=c)&&(~strcmp(AnnotationSymbol,'NC'))
                EndTrackNdx(i,ndx)=1;
            end
        end
    end
        
    %rho
    rho=zeros(r,c);
    threshold=tbl.CorrelationThreshold{1}; %same threshold for all cells in tbl   
%     disp(['Processing rho = ' num2str(threshold)]);
    for i=1:r 
       ndx=tbl.rho{i}<0; %get ndx for cells with rho<0 (occurs @ higher freq. with small search radius)
       if sum(ndx)>0
           tbl.rho{i}(ndx)=0;
       end
       rho(i,tbl.Image_Number{i})=arrayfun(@(x) x<threshold,tbl.rho{i});
       
    end
    
    if condition==1
        if sum(ndx)>0
            classification.lost(ndx)=0;
        end
      condition=(classification.pause|classification.lost); %condition should have stopped
    end
        
    %true positive
    classification.TP = ~rho & ~classification.pause & ~condition & (MidTrackNdx);
%     classification.TP= classification.TP | (~rho & ~classification.pause  & condition &  (MidTrackNdx));  

    %false negative
    classification.FN= rho & ~classification.pause & ~condition & (MidTrackNdx);
%     classification.FN= classification.FN | (~rho & classification.pause  & ~condition &  (MidTrackNdx));  
        
    %true negative
    classification.TN= rho & ~classification.pause & condition & (MidTrackNdx);
%     classification.TN = classification.TN | (rho & classification.pause & condition & (MidTrackNdx));
    %false positive
    classification.FP= ~rho & classification.pause  & condition &  (MidTrackNdx); 
%  classification.FP= classification.FP | (rho & classification.pause  & condition &  (MidTrackNdx));   
%    classification.FP= classification.FP | (~rho & classification.pause  & ~condition &  (MidTrackNdx));   

 
    x=classification.TP+classification.FN;
    ROC.TotalPositives=sum(x(:));
    x=classification.TN+classification.FP;
    ROC.TotalNegatives=sum(x(:));
    ROC.TP=sum(classification.TP(:));
    ROC.FP=sum(classification.FP(:));
    ROC.TN=sum(classification.TN(:));
    ROC.FN=sum(classification.FN(:));
    ROC.TPR=sum(classification.TP(:))/ROC.TotalPositives;
    ROC.FPR=sum(classification.FP(:))/ROC.TotalNegatives;

        %get tracking time
    TrackingTime=NaN(r,c);
    for i=1:r
        ndx=tbl.Image_Number{i};
        TT=tbl.Tracking_Time{i};
        TT=TT(2:end)-TT(1:end-1);
        TT=TT*24*60*60;
        TrackingTime(i,ndx(1:end-1))=TT;
    end

end


function stats=getCost(TruthSetTbl)
%% plots statistics for time spent correcting 'pause' or 'lost cell'
% tbl is the truthset table
    [ classification,TrackingTime,ROC ] = getPerformance( TruthSetTbl );
    t_pause=TrackingTime(classification.pause);
    t_lost=TrackingTime(classification.lost);
    t_go=TrackingTime(classification.go);
    % ECDF
%     close all;
    figure('Name','TruthSet: Empirical Distribution Function');
    [f,x,flo,fup]=ecdf(t_go);
    h_go=stairs(x,f,'-k');    
    hold on;
    stairs(x,flo,':k');
    stairs(x,fup,':k');
    [f,x,flo,fup]=ecdf(t_lost);
    h_lost=stairs(x,f,'-b');
    stairs(x,flo,':b');
    stairs(x,fup,':b');
    if isempty(t_pause)        
        t_pause=12; % have at least one pause of 12 second (usual time taken to correct when user issues a pause)
    end
    [f,x,flo,fup]=ecdf(t_pause);
    h_pause=stairs(x,f,'-r');
    stairs(x,flo,':r');
    stairs(x,fup,':r');
    set(gca,'XScale','log');
    xlabel('Step tracking time (seconds)');
    ylabel('Probability');
    legend([h_go h_lost h_pause],{'Automated' 'Machine lost cell' ...
        'User pauses tracking'},'Location','southeast');
    title('Empirical Cumulative Distribution');
    hold off;
    % pie chart    
    figure('Name','Truth set: tracking outcomes');
    subplot(1,2,1);
    X=[length(t_go),length(t_lost),length(t_pause)];
    pie(X,...
        {['Auto (' num2str(X(1)) ')'],...
        ['Lost (' num2str(X(2)) ')'],...
        ['Paused (' num2str(X(3)) ')']});
    title('Number of steps');
    subplot(1,2,2);
    X=[sum(t_go(~isnan(t_go))),sum(t_lost(~isnan(t_lost))),sum(t_pause(~isnan(t_pause)))];
    pie(X,...
        {['Auto (' num2str(round(X(1))) ')'],...
        ['Lost (' num2str(round(X(2))) ')'],...
        ['Paused (' num2str(round(X(3))) ')']});
    title('Total duration (seconds)');
    % box plot
    figure('Name','Truth set:  tracking time');
    X=[t_go(:);t_lost(:);t_pause(:)];
    g=[ones(length(t_go),1);2*ones(length(t_lost),1);3*ones(length(t_pause),1)];
    boxplot(X,g);
    set(gca,'YScale','log');
    set(gca,'XTickLabel',{'Auto' 'Lost' 'Pause'});
    ylabel('Step duration (seconds)');
    xlabel('Step outcome');
    
    % Summary statistics
    t_go=t_go(~isnan(t_go));
    t_pause=t_pause(~isnan(t_pause));
    t_lost=t_lost(~isnan(t_lost));
    stats.median.go=median(t_go);
    stats.median.pause=median(t_pause);
    stats.median.lost=median(t_lost);
    stats.median.all=median([t_go(:);t_pause(:);t_lost(:)]);
    stats.mean.go=mean(t_go);
    stats.mean.pause=mean(t_pause);
    stats.mean.lost=mean(t_lost);
    stats.mean.all=mean([t_go(:);t_pause(:);t_lost(:)]);
    stats.std.go=std(t_go);
    stats.std.pause=std(t_pause);
    stats.std.lost=std(t_lost);
    stats.std.all=std([t_go(:);t_pause(:);t_lost(:)]);
    [~,p]=ttest2(t_go,t_lost);
    stats.Pvalue.go_vs_lost=p;
    [~,p]=ttest2(t_lost,t_pause);
    stats.Pvalue.lost_vs_pause=p;
    [~,p]=ttest2(t_go,t_pause);
    stats.Pvalue.go_vs_pause=p;
end

