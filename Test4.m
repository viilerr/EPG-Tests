clear
close all
clc

addpath(genpath('EPGX_functions'))


nrefocus = 25;
nslice = 1:2:15;
nn  = length(nslice);
ESP = 7.7;
TR = 5000;

%rf pulses
a0 = {};
a0{1} = deg2rad([90 180*ones(1,nrefocus)]);
a0{2} = deg2rad([90 160 120*ones(1,nrefocus-1)]);
b1sqrdtau = {};
b1sqrdtau{1} = [32.7 213.1*ones(1,nrefocus)];
b1sqrdtau{2} = [36.7 189.4 106.5*ones(1,nrefocus-1)];
df = [10.9 12.27] * 42.57e3 * 6e-3;


T2b = 12e-6;
[ff,G] = SuperLorentzian(T2b);
sig = {};
JX = 1;

for IX = 1:2

    switch IX
        case 1
            f = 0.1166;
            kf = 4.3e-3;
            kb = kf * (1-f)/f;
            R1f = 1/779;
            R1b = 1/779;
            R2f = 1/45;

        case 2
            f = 0.0610;
            kf = 2.3e-3;
            kb = kf * (1-f)/f;
            R1b = 1/1087;
            R1f = 1/1087;
            R2f = 1/59;
    end

    for JX = 1:2

        for jj = 1:nn

            slice_order = [1:2:nslice(jj) 2:2:nslice(jj)];
            soi = ceil(nslice(jj)/2);
            fs = df(JX) * (-floor(nslice(jj)/2):floor(nslice(jj)/2));
            GG = interp1(ff,G,fs);
            Nsl = length(slice_order);
            Ntr = 4;
            slice_order = repmat(slice_order,[1 Ntr]);
            Ntot = Ntr * Nsl;
            Tshot = ESP*(nrefocus+0.5);
            Tdelay = TR/nslice(jj) - Tshot;
            L = [[-R1f-kf kb];[kf -R1b-kb]];
            C = [R1f*(1-f) R1b*f]';
            Xi = expm(L*Tdelay);
            Zoff = (Xi - eye(2))*(L\C);
            z0 = [(1-f) f];
            ss = [];

            for ii = 1:Ntot

                if slice_order(ii) == soi
                    [s,Fn,Zn] = EPGX_TSE_MT(a0{JX},b1sqrdtau{JX},ESP,...
                        [1/R1f 1/R1b],1/R2f,f,kf,GG(soi),'zinit',z0);
                    ss = cat(2,ss,s(:));
                else
                    [s,Fn,Zn] = EPGX_TSE_MT(a0{JX}*0,b1sqrdtau{JX},ESP,...
                        [1/R1f 1/R1b],1/R2f,f,kf,GG(slice_order(ii)),'zinit',z0);
                end

                z0 = squeeze(Zn(1,end,:));
                z0 = Xi*z0 + Zoff;
            end

            sig{JX}(jj,IX) = abs(ss(13,end));
        end
    end
end

sig{1}(:,3) = 1;
sig{2}(:,3) = 1;


load('test4_imagedata.mat')
leg = {'White Matter','Gray Matter (Caudate)','Cerebrospinal Fluid'};


figure(21)
clf
nr = 3; 
nc = 3;
fs = 18;
sl = [1 4 8];

subplot(nr,nc,1)
img = abs(ims{1,1});
img = rot90(img,-1);
img = (img-200)/1000;
img = max(min(img,1),0);
imagesc(img)
colormap gray
axis image off
title('Single slice TSE','fontsize',fs)

for ii = 2:nc
    subplot(nr,nc,ii)

    img = ims{sl(ii),1};
    img = rot90(img,-1);
    img = double(img);
    img = (img-200)/(1200-200);
    img = max(min(img,1),0);
    imagesc(img)
    colormap gray
    axis image off
    title(sprintf('Multislice (%d slices)',nslice(sl(ii))),...
        'fontsize',fs)
end

subplot(nr,nc,4)
axis off
text(0.5,0.5,'180° pulses',...
    'rotation',90,'fontsize',18,...
    'fontweight','bold',...
    'horizontalalignment','center')
subplot(nr,nc,7)
axis off
text(0.5,0.5,'120° pulses',...
    'rotation',90,'fontsize',18,...
    'fontweight','bold',...
    'horizontalalignment','center')

for kk = 1:2
    for ii = 1:3

        subplot(nr,nc,ii + nc*(kk-1) + nc)
        cla reset          
        hold on
        grid on
        box on            

y = sig{kk}(:,ii) ./ sig{kk}(1,ii);
plot(nslice, y, '-or', ...
    'LineWidth', 1.5, ...
    'MarkerFaceColor', 'r', ...
    'MarkerSize', 8);

        ylim([0.55 1.15])
        xlim([0 16])
        set(gca,'fontsize',12)
        set(gca,'XTickMode','auto','YTickMode','auto')
        set(gca,'XColor','k','YColor','k')

        if kk == 1
            title(leg{ii})
        else
            xlabel('Number of slices')
        end

        ylabel('signal (au)')
    end
end