function chitcalibrate(sbdir,unit,ttop,tbot,polinom_order)
% unit is chipod unit number(integer)
% ttop is top sensor ID, tbot is bottom sensor ID (strings)
% sbdir is a directory where seabird data are saved
% chipod data should be under sbdir\num2str(unit)\
%  modified to make sure it prints right figures from gui call
%  and not the figure of the gui itself
%
%  This version also uses only 2nd order polynomial fit
%  MJB  7/10/13


polinom_order=2;

%% Load and plot data 
load([sbdir '\' num2str(unit) '_T']);
if length(chi.time)==2*length(chi.T1)
    chi.time=chi.time(1:2:end);
end
coeff.T1=[0 0 0 0 0];
coeff.T2=[0 0 0 0 0];
tlims=[min(sbe.temp)-1 max(sbe.temp)+1];
% plot the data
fig1hdl = figure(1); clf;
s(1)=subplot(2,1,1);
plot(sbe.time,sbe.temp,'k.')
datetick
title('Seabird')
set(gca,'xlim',[sbe.time(1) sbe.time(end)])
s(2)=subplot(2,1,2);
hold on
plot(chi.time,chi.T1,'b.')
if isfield(chi,'T2')
    plot(chi.time,chi.T2,'r.')
end
kdatetick
if isfield(chi,'T2')
    legend(['T1: ' ttop],['T2: ' tbot],'location','best')
else
    legend(['T1: ' ttop],'location','best')
end
title(['Chipod ' num2str(unit)])
set(gca,'xlim',[sbe.time(1) sbe.time(end)])
linkaxes(s,'x')
print(fig1hdl,'-dpng','-r200',[sbdir '\' num2str(unit) 'seabird_T']);

%% calibrate  top thermistor
clear cal
for ii=1:max(sbe.count)
    in=find(sbe.count==ii);
    sbt=sbe.temp(in);
    time=sbe.time(in);
%     good=find(time>time(1)+1/24/12 & time<time(end)-1/24/12);
%  shrink in the time used by calculations by 6 minutes each end
    good=find(time>time(1)+1/24/10 & time<time(end)-1/24/10);
    time=time(good);
    % find the Seabird  mean value over the shrunken interval
    cal.sbt(ii)=nanmean(sbt(good));
      % find the Chipod mean value over the shrunken interval
    cal.chiv(ii)=nanmean(chi.T1(chi.time>time(1) & chi.time<time(end)));
end  
good=find(~isnan(cal.chiv));
if ~isempty(good)
    cal.chiv=cal.chiv(good);
    cal.sbt=cal.sbt(good);
end
v=min(cal.chiv):0.01:max(cal.chiv); 
p=polyfit(cal.chiv,cal.sbt,polinom_order);
coeff.T1(1:polinom_order+1)=fliplr(p);

% coeff.T1=head.coef.T1;
fig3hdl = figure(3); clf;
subplot(3,1,1)

%assume polinom_order==2
    plot(v,coeff.T1(1)+coeff.T1(2).*v+coeff.T1(3).*v.^2,'b-')
    title(['Unit ' num2str(unit) ' T1 (' ttop '): ' num2str(coeff.T1(1)) ' + ' num2str(coeff.T1(2))...
        '\cdotV + ' num2str(coeff.T1(3)) '\cdotV^2'])

if ~isnan(v)
    set(gca,'ylim',tlims,'xlim',[min(v) max(v)]);
end
xlabel('V')
ylabel('Fit T')
subplot(3,1,2)
plot(cal.sbt,'k.','markersize',10)
hold on
%assume  polinom_order==2
    plot(coeff.T1(1)+coeff.T1(2).*cal.chiv+coeff.T1(3).*cal.chiv.^2,'b.','markersize',10)

legend('Seabird T','Chipod T1','location','best')
ylabel('T [\circC]')
subplot(3,1,3)
%assume polinom_order==2
    plot(coeff.T1(1)+coeff.T1(2).*cal.chiv+coeff.T1(3).*cal.chiv.^2-cal.sbt,'c.','markersize',10)

legend('Chipod T1 - Seabird T','location','best')
ylabel('T [\circC]')
print(fig3hdl,'-dpng','-r200',[sbdir '\' num2str(unit) 'T1cals']);
if isfield(chi,'T2')
clear cal
for ii=1:max(sbe.count)
    in=find(sbe.count==ii);
    sbt=sbe.temp(in);
    time=sbe.time(in);
    good=find(time>time(1)+1/24/12 & time<time(end)-1/24/12);
    time=time(good);
    cal.sbt(ii)=nanmean(sbt(good));
    cal.chiv(ii)=nanmean(chi.T2(chi.time>time(1) & chi.time<time(end)));
end    
good=find(~isnan(cal.chiv));
if ~isempty(good)
    cal.chiv=cal.chiv(good);
    cal.sbt=cal.sbt(good);
end
v=min(cal.chiv):0.01:max(cal.chiv); 
p=polyfit(cal.chiv,cal.sbt,polinom_order);
coeff.T2(1:polinom_order+1)=fliplr(p);

fig4hdl = figure(4); clf;
subplot(3,1,1)
%assume polinom_order==2
    plot(v,coeff.T2(1)+coeff.T2(2).*v+coeff.T2(3).*v.^2,'r-')
    title(['Unit ' num2str(unit) ' T2 (' tbot '): ' num2str(coeff.T2(1)) ' + ' num2str(coeff.T2(2))...
        '\cdotV + ' num2str(coeff.T2(3)) '\cdotV^2'])

if ~isnan(v)
    set(gca,'ylim',tlims,'xlim',[min(v) max(v)]);
end
xlabel('V')
ylabel('Fit T')
subplot(3,1,2)
plot(cal.sbt,'k.')
hold on
%assume  polinom_order==2
    plot(coeff.T2(1)+coeff.T2(2).*cal.chiv+coeff.T2(3).*cal.chiv.^2,'r.','markersize',10)
legend('Seabird T','Chipod T2','location','best')
ylabel('T [\circC]')
subplot(3,1,3)
%assume polinom_order==2
    plot(coeff.T2(1)+coeff.T2(2).*cal.chiv+coeff.T2(3).*cal.chiv.^2-cal.sbt,'m.','markersize',10)
legend('Chipod T2 - Seabird T','location','best')
ylabel('T [\circC]')
print(fig4hdl,'-dpng','-r200',[sbdir '\' num2str(unit) 'T2cals']);
end
save([sbdir 'calcoeff' num2str(unit)],'coeff')
