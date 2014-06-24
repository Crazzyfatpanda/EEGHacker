
%given_amp_counts = 4.5/2.4e-3;

f_lim = [0 22];
t_lim=[];
pname = 'SavedData\';
truth=[];intended=[];
switch 5
    case 2
        fname = 'openBCI_raw_2014-05-31_20-48-01_Robot02.txt'; chans=[2];
    case 3
        fname = 'openBCI_raw_2014-05-31_20-51-30_Robot03.txt'; chans=[2];
    case 4
        fname = 'openBCI_raw_2014-05-31_20-55-29_Robot04.txt'; chans=[2];
    case 5
        fname = 'openBCI_raw_2014-05-31_20-57-51_Robot05.txt'; chans=2;  t_lim=[0 135];%this might be the one from the movie
        truth = [12	19	2
            31	34	3
            39	40	1
            48	51	1
            57	59	3
            60	62	2
            66	69	3
            81	84	1
            90	94	3
            101	105	3
            106	109	1
            114	119	3
            121	122	2];  %start time, end time, action code...1 = left, 2  = right, 3 = fwd
        truth_start_sec = 16.22;a
        intended = [27 34 1
            36  51  1
            56  62  2
            65  69  3
            74  83  1
            87  94  3
            100 109 1
            112 119 3];
        intended(:,1:2) = intended(:,1:2)+1;
    case 9
        fname = 'openBCI_raw_2014-05-31_21-07-40_Robot09.txt'; chans=2;
    case 11
        fname = 'openBCI_raw_2014-05-31_21-15-57_Robot11.txt'; chans = 2;  %alpha, then 7.5 Hz sustained
    case 12
        fname = 'openBCI_raw_2014-05-31_21-17-28_Robot12.txt'; chans = 2;
end
scale_fac_volts_count=2.23e-8;

%% process truth data
time_offset_sec = truth_start_sec - truth(1,1);
if (1)
    %use "intended" instead of truth
    disp(['Using "intended" commands instead of actual robot actions...']);
    truth = intended;
end

if ~isempty(truth)
    truth_sec = truth(:,1:2);
    truth_sec = truth_sec + time_offset_sec;
    truth_code = truth(:,3);
else
    truth_sec = [];
    truth_code=[];
end

%% load data
data_uV = load([pname fname]);  %loads data as microvolts
data_uV = data_uV(:,[1 chans+1 size(data_uV,2)]);  %get aux, too
%fs = data2.fs_Hz;
fs = 250;
count = data_uV(:,1);  %first column is a packet counter (though it's broken)
data_V = data_uV(:,2:end) * 1e-6; %other columns are data
clear data_uV;

%% filter data
data_V = data_V - ones(size(data_V,1),1)*mean(data_V);
%[b,a]=butter(2,[0.2 50]/(fs/2));
[b,a]=butter(2,0.2/(fs/2),'high');
data_V = filter(b,a,data_V);
[b,a]=butter(3,[55 65]/(fs/2),'stop');
data_V = filter(b,a,data_V);


%% plot data
t_sec = ([1:size(data_V,1)]-1)/fs;
nrow = 3; ncol=1;
ax=[];
figure;setFigureTallestWide;
for Ichan=1:1
    
    %spectrogram
    subplot(nrow,ncol,Ichan);
    N=512;overlap = 1-50/N;plots=0;  %this is the overlap in the processing GUI
    [pD,wT,f]=windowedFFTPlot_spectragram(data_V(:,Ichan)*1e6,N,overlap,fs,plots);
    wT = wT + (N/2)/fs;
    
    %FFT Averaging (in dB space)
    smooth_txt=[];
    if (1)
        pD_dB = 10*log10(pD);
        smooth_fac = 0.9;
        smooth_txt = ['Smooth Fac: ' num2str(smooth_fac)];
        b = 1-smooth_fac; a = [1 -smooth_fac];
        pD_dB = filter(b,a,pD_dB')';  %transpose to smooth across columns
        pD = 10.^(0.1*pD_dB);
    end
    
    %continue plotting
    imagesc(wT,f,10*log10(pD));
    set(gca,'Ydir','normal');
    xlabel('Time (sec)');
    ylabel('Frequency (Hz)');
    title([fname ', Channel ' num2str(chans(Ichan))],'interpreter','none');
    %set(gca,'Clim',+25+[-40 0]+10*log10(256)-10*log10(N));
    set(gca,'Clim',[-15 15]);
    if ~isempty(t_lim)
        xlim(t_lim);
    else
        xlim(t_sec([1 end]));
    end
    xl=xlim;
    ylim(f_lim);
    cl=get(gca,'Clim');
    txt = {['fs: ' num2str(fs) ' Hz, N: ' num2str(N) ', Step: ' num2str(round(N*(1-overlap)))];['Clim = [' num2str(round(cl(1))) ' ' num2str(round(cl(2))) '] dB']};
    if ~isempty(smooth_txt); txt{end+1}=smooth_txt;end
    h=weaText(txt,2);
    set(h,'BackgroundColor','white');
    colorbar;
    clabel(['uV/sqrt(Hz) (dB)']);
    ax(end+1)=gca;
    
    %    %compute SNR
    inband_Hz = [4 15];
    Ifreq=find((f >= inband_Hz(1)) & (f <= inband_Hz(2)));
    [peak_pD,Ipeak]=max(pD(Ifreq,:));
    ave_noise_pD = zeros(size(peak_pD));
    %loop and get noise (excluding peak) for each time
    for Itime=1:length(ave_noise_pD)
        foo_pD = pD(Ifreq,Itime);
        foo_pD(Ipeak(Itime)) = NaN;
        if (Ipeak(Itime) > 1);foo_pD(Ipeak(Itime)-1) = NaN;end;
        if (Ipeak(Itime) < length(foo_pD)); foo_pD(Ipeak(Itime)+1) = NaN;end;
        ave_noise_pD(Itime) = nanmean(foo_pD);
    end
    peak_freq_Hz = f(Ifreq(Ipeak));
    snr_dB = 10*log10(pD ./ (ones(size(pD,1),1)*ave_noise_pD));
    peak_SNR_dB = zeros(size(peak_freq_Hz));
    for Itime=1:length(peak_SNR_dB);
        peak_SNR_dB(Itime) = snr_dB(Ifreq(Ipeak(Itime)),Itime);
    end
    t_snr_sec = wT;
    
    %continue plotting
    for Iplot=1:2
        subplot(nrow,ncol,Ichan+Iplot);
        foo_dB = snr_dB;
        
        imagesc(wT,f,foo_dB);
        set(gca,'Ydir','normal');
        xlabel('Time (sec)');
        ylabel('Frequency (Hz)');
        title([fname ', Channel ' num2str(chans(Ichan))],'interpreter','none');
        set(gca,'Clim',[-10 10]);
        set(gca,'Clim',[-5 10]);
        xlim(xl);
        ylim(f_lim);
        cl=get(gca,'Clim');
        %h=weaText({['Nfft = ' num2str(N) ', fs = ' num2str(fs) ' Hz'];['Clim = [' num2str(round(cl(1))) ' ' num2str(round(cl(2))) '] dB']},1);
        h = weaText(txt,2);
        set(h,'BackgroundColor','white');
        clabel(['SNR (dB)']);
        
        
        det_thresh_dB = 6;
        I=find(peak_SNR_dB > det_thresh_dB);
        if (Iplot==2)
            hold on; plot(t_snr_sec(I),peak_freq_Hz(I),'wo','linewidth',2); hold off;
            
            %freq_bounds = [4 6.5 9 12 15];
            freq_bounds = [4 6.5 9 12];
            for Ibound=1:length(freq_bounds);
                hold on;
                plot(xlim,freq_bounds(Ibound)*[1 1],'w--','linewidth',2);
                hold off;
            end
            
            %add truth bounds
            truth_to_freq_code = [2 1 3];
            for Itruth=1:size(truth_sec,1)
                hold on;
                y = freq_bounds(truth_to_freq_code(truth_code(Itruth))+[0 1]);
                plot(truth_sec(Itruth,1)*[1 1],y,'k:','linewidth',2);
                plot(truth_sec(Itruth,2)*[1 1],y,'k:','linewidth',2);
                hold off;
            end
            
            
        end
        ax(end+1)=gca;
    end
end
linkaxes(ax);

%% get SNR spectrum per time region
SNR_spectra = {};
median_SNR_dB = [];
std_SNR_dB=[];
for Itype = 1:3
    all_SNR_dB=[];%clear
    for Itruth=1:size(truth_sec,1)
        if (truth_code(Itruth) == Itype)
            Itime=find((wT >= truth_sec(Itruth,1)) & (wT <= truth_sec(Itruth,2)));
            all_SNR_dB = [all_SNR_dB snr_dB(:,Itime)];
        end
    end
    SNR_spectra{Itype} = all_SNR_dB;
    median_SNR_dB(:,Itype) = mean(all_SNR_dB')';
    std_SNR_dB(:,Itype) = std(all_SNR_dB')';
end

%process each time slice
det_freq_bounds = [[freq_bounds(1:end-1)'; 15-1.5] [freq_bounds(2:end)';  15+1.5]];
peak_SNR_per_band_dB = NaN*ones(length(wT),size(det_freq_bounds,1));
for Iband=1:size(det_freq_bounds,1);
    Ifreq=find((f>=det_freq_bounds(Iband,1)) & (f<=det_freq_bounds(Iband,2)));
    for Itime=1:length(wT)
        peak_SNR_per_band_dB(Itime,Iband) = max(snr_dB(Ifreq,Itime));
    end
end

%define truth of each time slice
truth_perSlice=zeros*ones(size(wT));
I=find(wT < truth_sec(1,1)-3);
truth_perSlice(I) = NaN;  %ignore
for Itruth=1:length(truth_code)
    %find time slices that precede the window
    I=find((wT >= truth_sec(Itruth,1)-1) & (wT <= truth_sec(Itruth,1)));
    truth_perSlice(I) = NaN;  %ignore
    
    %find time slices that are within the window
    I=find((wT >= truth_sec(Itruth,1)) & (wT <= truth_sec(Itruth,2)));
    truth_perSlice(I) = truth_code(Itruth);
    
    %find the time slices that just follow the window
    I=find((wT > truth_sec(Itruth,2)) & (wT <= (truth_sec(Itruth,2)+1.5)));
    truth_perSlice(I) = NaN;  %igore all of these points
end
I=find(wT > truth_sec(end,2));
truth_perSlice(I) = NaN;  %ignore


%% plot the spectrum analysis
figure;setFigureTallerWide;
for Iplot=1:2
    subplot(3,2,Iplot);
    plot(f,median_SNR_dB,'linewidth',2);
    legend('Left','Right','Forward');
    xlim([0 22]);
    ylim([-3 12]);set(gca,'YTick',[-3:3:12]);
    %hold on;plot(xlim,[0 0],'k--','linewidth',2);
    ylabel(['Mean of dB SNR']);
    if (Iplot==2)
        hold on;
        for Ibound=1:length(freq_bounds);
            plot(freq_bounds(Ibound)*[1 1],ylim,'k--','linewidth',2);
        end
        hold off;
    end
end

subplot(3,1,2);
plot(wT,peak_SNR_per_band_dB,'linewidth',2);
xlabel('Time (sec)');
ylabel('SNR (dB)');
ylim([-3 12]);set(gca,'YTick',[-3:3:12]);
xlim(t_lim);
legend('Band 1','Band 2','Band 3','Band 4',2);

subplot(3,1,3);
plot(wT,truth_perSlice,'o','linewidth',2);
set(gca,'YTick',[0 1 2 3],'YTickLabel',{'None','Left','Right','Forward'});
ylim([0 3]+[-1 1]);
xlim(t_lim);
ylabel('Truth Code');
xlabel('Time (sec)');

for Iplot=2:3
    subplot(3,1,Iplot);
    hold on;
    txt=['LRF'];
    for Itruth=1:size(truth_sec,1)
        plot(truth_sec(Itruth,1)*[1 1],ylim,'k:','linewidth',2);
        plot(truth_sec(Itruth,2)*[1 1],ylim,'k:','linewidth',2);
        yl=ylim;
        text(mean(truth_sec(Itruth,:)),yl(2)-0.05*diff(yl),txt(truth_code(Itruth)),...
            'HorizontalAlignment','Center','VerticalAlignment','Top',...
            'BackgroundColor','white','FontWeight','Bold');
    end
    hold off
end

%% comparison of metrics
figure;setFigureTallestWidest;
nrow=3;
ncol=4;
Iplot=0;
c = [0.25 0.25 0.25; 0 0 1; 0 0.5 0; 1 0 0;];
sym = 'xooo';
loc = [1 5 9 2 6 10 3 7 11 4 8 12];
for Icompare=1:4
    for Jcompare = 1:4
        if Icompare ~= Jcompare
            Iplot=Iplot+1;
            subplotTightBorder(nrow,ncol,loc(Iplot));
            for Itype=0:3
                I=find(truth_perSlice==Itype);
                hold on;
                x = peak_SNR_per_band_dB(I,Icompare);
                y = peak_SNR_per_band_dB(I,Jcompare);
                h=plot(x,y,sym(Itype+1),'linewidth',2,'Color',c(Itype+1,:));
                if (Itype==0)
                    set(h,'MarkerSize',8,'linewidth',3);
                end
            end
            axis equal;
            axis square;
            xlim([-3 10]);ylim(xlim);
            set(gca,'Xtick',[-3:3:12]);
            set(gca,'Ytick',[-3:3:12]);
            
            xlabel(['Band ' num2str(Icompare)]);
            ylabel(['Band ' num2str(Jcompare)]);
            box on
            if (Iplot==1);legend('Noise','Left','Right','Forward',1);end
        end
    end
end

