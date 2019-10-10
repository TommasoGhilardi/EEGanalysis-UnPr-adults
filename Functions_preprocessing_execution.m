classdef Functions_preprocessing_execution
    methods(Static) 
        
        function [cfg_tr_def,events] = Trialdef_execution(path)
            cfg             = [];
            cfg.dataset     = path;
            cfg.trialfun    = 'trial_fun_execution';
            cfg_tr_def      = ft_definetrial(cfg);   % read the list of the specific stimulus
            events          = cfg_tr_def.event;
        end
        
        function [cfg_tr_def,events] = Trialdef_baseline(path)
            cfg             = [];
            cfg.dataset     = path;
            cfg.trialfun    = 'trial_fun_baseline';
            cfg_tr_def      = ft_definetrial(cfg);   % read the list of the specific stimulus
            events          = cfg_tr_def.event;
        end
        
        function [result] = Preprocess(cfg,hp,lp)
            % read data and segment
            cfg.hpfilter    = 'yes';        % enable high-pass filtering
            cfg.lpfilter    = 'yes';        % enable low-pass filtering
            cfg.hpfreq      = hp;           % set up the frequency for high-pass filter
            cfg.lpfreq      = lp;
            cfg.detrend     = 'yes';
            cfg.demean      = 'yes';
            result          = ft_preprocessing(cfg); % read raw data
            if isequal(result.label{end},'FP1')
                result.label{end}='Fp1';
            else
                disp('ERROR FP1... CHECK PLEASE')
            end
        end 
        
        function [result] = Visual_rejection(input,what)

            if what > 0
                % Visual rejection with summary
                cfg = [];
                cfg.metric      = 'kurtosis';  % use by default zvalue method
                cfg.method      = 'summary'; % use by default summary method
                result    = ft_rejectvisual(cfg,input);

                if what > 1
                    % Trial rejection
                    cfg = [];
                    cfg.method  = 'trial';
                    result        = ft_rejectvisual(cfg,result);
                
                    if what > 2
                        % Rereference to average
                        cfg.reref       = 'yes';
                        cfg.refchannel  = 'all';
                        cfg.refmethod   = 'avg';
                        result          = ft_preprocessing(cfg,result);
            
                    end
                end
            end
        end
        
        function[result] = ICA(input,components,cap)
            cfg             = [];
            cfg.method      = 'runica'; % default implementation from EEGLAB
            comp            = ft_componentanalysis(cfg, input);

            % plot the components for visual inspection
            figure('units','normalized','outerposition',[0 0 1 1])
            cfg             = [];
            cfg.marker      = 'labels';
            cfg.component   = 1:components;       % specify the component(s) that should be plotted
            cfg.layout      = cap; % specify the layout file that should be used for plotting
            cfg.comment     = 'no';
            
            ft_topoplotIC(cfg, comp)

            prompt      = {'Components to reject: '};
            dlgtitle    = 'Input';
            dims        = [1 60];
            answer      = inputdlg(prompt,dlgtitle,dims);
            if isempty(answer)
                answer=[];
            else
                answer      = str2num(char(answer{1}));
            end
            %rejecting
            cfg             = [];
            cfg.component   = answer; % to be removed component(s)
            result          = ft_rejectcomponent(cfg, comp, input);
            close
        end
        
        function [result] = FFT(input,channel)
            %FFT decomposition
            cfg              = [];
            cfg.output       = 'pow';
            cfg.channel      = 'EEG';
            cfg.method       = 'mtmfft';
            cfg.taper        = 'hanning';
            cfg.pad          = 'maxperlen';
            cfg.padtype      = 'zero';
            cfg.channel      = channel;
            cfg.keeptrials   = 'yes';
            cfg.foi          = 3:1:30; % analysis 3 to 30 Hz in steps of 1 Hz
            result           = ft_freqanalysis(cfg, input);
        end
        
        function [] = Plot_fft(Freq1,Freq2,square)
            data1   = Freq1.powspctrm;
            data2   = Freq2.powspctrm;
            x1      = Freq1.freq;
            x2      = Freq2.freq;

            blu_area    = [128 193 219]./255;    % Blue theme
            blu_line    = [ 52 148 186]./255;
            orange_area = [243 169 114]./255;    % Orange theme
            orange_line = [236 112  22]./255;
            alpha       = 0.2;
            line_width  = 2;

            % Computing the mean and standard deviation of the data matrix
            data_mean1  = mean(data1,1);
            data_mean2  = mean(data2,1);
            data_std1   = std(data1,0,1);
            data_std2   = std(data2,0,1);
            % Type of error plot
            error1      = (data_std1./sqrt(size(data1,1)));
            error2      = (data_std2./sqrt(size(data2,1)));

            figure;
            a=subplot(2,1,1);
            hold on
            %first line
            patch = fill([x1, fliplr(x1)], [data_mean1+error1, fliplr(data_mean1-error1)], blu_area);
            set(patch, 'edgecolor', 'none');
            set(patch, 'FaceAlpha', alpha);
            plott(1)=plot(x1, data_mean1,'color', blu_line,'LineWidth', line_width);
            %second line
            patch = fill([x2, fliplr(x2)], [data_mean2+error2, fliplr(data_mean2-error2)], orange_area);
            set(patch, 'edgecolor', 'none');
            set(patch, 'FaceAlpha', alpha);
            plott(2)=plot(x2, data_mean2,'color', orange_line,'LineWidth', line_width);
            xlabel('Frequency (Hz)');
            ylabel('absolute power (uV^2)');
            legend(plott,{'Execution','Baseline'});
            xlim([2.5 31]);

            subplot(2,1,2);
            hold on
            Freq=Freq1;
            Freq.powspctrm=Freq1.powspctrm-Freq2.powspctrm;
            [peaksY,peaksX,w,p]     = findpeaks(-mean(Freq.powspctrm(:,:)));
            xpeaks                  = Freq.freq(peaksX);
            ind_peaks               = find(Freq.freq(peaksX)>7 & Freq.freq(peaksX)<13);

            width                   = w(ind_peaks);
            xlabel('Frequency (Hz)');
            ylabel('absolute power (uV^2)');
            xlim([2.5 31]);
            if square == 'yes'
                x= xpeaks(ind_peaks)- width/2;
                rectangle('Position',[x -7 width 15],'FaceColor',[0 0 0 0.1],'EdgeColor',[0 0 0 0.1]...
                    ,'Curvature',0.1);
            end
            plot(Freq.freq, mean(Freq.powspctrm(:,:)),'k',...
                xpeaks(ind_peaks),-peaksY(ind_peaks),'ro','LineWidth',1);
            ylim([-4 0.4]);
            legend('Execution-Baseline');
            disp(['Peak at:  ', num2str(xpeaks(ind_peaks)),'Hz']);
        end
        
        function [] = Saving_range(path)
            %name
            Sub =cell2table({path(1:length(path)-4)},'VariableNames',{'Sub'});
            %freq
            prompt      = {'What is the frequency peak: '};
            dlgtitle    = 'Input';
            dims        = [1 20];
            answer      = inputdlg(prompt,dlgtitle,dims);
            range       = str2num(char(answer{1}));

            if exist('U:\Desktop\Baby_BRAIN\Projects\EEG_probabilities_adults\Data\Raw data\Neural\Range_freq.csv','file')==2
                frq_range= readtable('Range_freq.csv');
                if sum(ismember(frq_range(:,1),Sub)) >= 1
                     dlgTitle    = 'User Question';
                     dlgQuestion = 'Already done...override?';
                     choice      = questdlg(dlgQuestion,dlgTitle,'Yes','No', 'Yes');
                     if choice == "Yes"
                         location=find(ismember(frq_range(:,1),Sub));
                         frq_range([location],:)= [];
                     end
                end  
                %add the columns
                for x = 1:length(range)
                   addition={table2cell(Sub), range(x)};
                   frq_range=[frq_range;addition];
                end
                writetable(frq_range,'Range_freq.csv','Delimiter',',');
                disp('SAVED')
                
            %crate the file if not existing    
            elseif  exist('U:\Desktop\Baby_BRAIN\Projects\EEG_probabilities_adults\Data\Raw data\Neural\Range_freq.csv','file')==0
                frq_range = table(table2cell(Sub),range);
                frq_range.Properties.VariableNames ={'Sub','range'};
                writetable(frq_range,'Range_freq.csv','Delimiter',',');
                disp('CREATED')
            else
                f           = msgbox('Problem with the File', 'Error','error');
                th          = findall(f, 'Type', 'Text');                   %get handle to text within msgbox
                th.FontSize = 16;
            end
        end
    end
end    