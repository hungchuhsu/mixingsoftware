function y=gappy_filt(sample_rate,filters,order,x,maxinterplen,fillgaps,ripple);
% function Y=GAPPY_FILT(SAMPLE_RATE,FILTERS,ORDER,X) filters X which is
% sampled at SAMPLE_RATE at freqs given by FILTERS.
% 
% The cell array FILTERS = {'h.05','l50','n20-21'} would highpass
% the data at 0.05 Hz, lowpass the data at 50 Hz, and notch it at 20-21 Hz
% new addition: ('b20-21') band passes between 20-21 Hz.
% 
% ORDER denotes filter order.
% 
% The form:
% Y=GAPPY_FILT(...,MAXINTERPLEN) may be used to specify the maximum gap
% over which to filter (default 0).  These gaps are interpolated over
% linearly prior to filtering.
% 
% The form:
% Y=GAPPY_FILT(...,MAXINTERPLEN,FILLGAPS) may be used to retain the
% filtered output in the gaps of length<MAXINTERPLEN.  FILLGAPS is simply
% a flag (0 or 1, default 0).
% 
% Y=GAPPY_FILT(...,MAXINTERPLEN,FILLGAPS,RIPPLE) may be used to use a
% cheby2 filter with ripple attenuation (in db) RIPPLE.  If RIPPLE==0
% (the default), a butterworth filter (again: default) is used.
% RIPPLE=20 is a good starting value if you do not know where to begin.
% 
% The function uses filtfilt on the good data, so the response
% funtion of the filter is squared...


if nargin<=6
  ripple=0;
end
if nargin<=5
  fillgaps=0;
end
if nargin<=4
  maxinterplen=0;
end

szx1=size(x,1);  
if ~iscell(filters); filters=cellstr(filters);  end
for j=1:length(filters)
  filts=lower(char(filters(j)));
  type=filts(1);
  if type=='l'
    % LOWPASS
    cutfreq=str2num(filts(2:length(filts)));
    if ripple>0
        [b,a]=cheby2(order,ripple,2*cutfreq/(sample_rate));
    else
        [b,a]=butter(order,2*cutfreq/(sample_rate));
    end
  elseif type=='h'
    % HIGHPASS
    cutfreq=str2num(filts(2:length(filts)));
    if ripple>0
        [b,a]=cheby2(order,ripple,2*cutfreq/(sample_rate),'high');
    else
        [b,a]=butter(order,2*cutfreq/(sample_rate),'high');
    end
  elseif type=='n'
    % NOTCH
    position=find(filts=='-');
    cutfreq1=str2num(filts(2:(position-1)));
    cutfreq2=str2num(filts((position+1):length(filts)));
    [b,a]=butter(order,2*[cutfreq1 cutfreq2]/(sample_rate),'stop');
    if ripple>0
        [b,a]=cheby2(order,ripple,2*[cutfreq1 cutfreq2]/(sample_rate),'stop');
    else
        [b,a]=butter(order,2*[cutfreq1 cutfreq2]/(sample_rate),'stop');
    end
  elseif type=='b'
    % bandpass
    position=find(filts=='-');
    passfreq1=str2num(filts(2:(position-1)));
    passfreq2=str2num(filts((position+1):length(filts)));
    if ripple>0
        [b,a]=cheby2(order,ripple,2*[passfreq1 passfreq2]/(sample_rate));
    else
        [b,a]=butter(order,2*[passfreq1 passfreq2]/(sample_rate));
    end
  end
end

if length(a)==1 && length(b)==1
  y = x;
  return;
end;

if size(x,2)>1 && size(x,1)>1
  % loop over columns...
  y=x;
  for i=1:size(x,2)
    y(:,i) = gappy_filt(sample_rate,filters,order,x(:,i),maxinterplen,fillgaps,ripple);
  end;
  return;
end;

x=double(x(:)); % convert rows to columns;
                % and make sure that input is double precision
                % filtfilt sometimes does not work with single precision
                % data
x(isinf(x)) = NaN;

% Initialize y:
y=NaN*x;

% Return if b & a are scalars:
if length(b)==1 && length(a) == 1
  return;
end;

% Find all non-nans and group the ones less than maxinterplen together:
nnan=group_diff(find(~isnan(x)),maxinterplen+1);

% Now loop over nnan:
for i0=1:length(nnan)
  gd=nnan{i0}(1):nnan{i0}(end);
  d=interp_missing_data(x(gd),maxinterplen);
  if length(d)>length(b) && (gd(end)-gd(1))/length(gd)<3
    L=length(b);
    d=[(2*d(1)-flipud(d(1:L)));d;2*d(end)-flipud(d((end-L+1):end))];
    dnew = filtfilt(b,a,d);
    y(gd) = dnew((1:length(gd))+L);
  elseif ~isempty(gd)
    y(gd) = NaN*mean(x(gd));
  end; 
end
if ~fillgaps
  y(isnan(x))=nan;
end
if size(y,1)~=szx1; y=y'; end

function out=group_diff(in,dmax)
% OUT=GROUP_DIFF(IN) groups the IN that are less than dmax
% apart consecutively into a length M cell array OUT, where each
% cell of OUT contains the consecutive values of IN that are less than
% dmax apart.
% 
% NOTE: unique(IN) is applied to IN before grouping takes place.  This
% sorts and eliminates repititions in IN.

in=unique(in);
inds=find(diff(in)>dmax & diff(in)~=0);
if( isempty(in)) 
  out={};
  return
end

i0 = 0 ; % this fix catches all cases where inds isempty w
tk=1;
if(~isempty(inds))
    for i0=1:length(inds)
      out{i0}=in(tk:inds(i0));
      tk=inds(i0)+1;
    end
end
out{i0+1}=in(tk:end);

function in=interp_missing_data(in,maxgap)
% interp_missing_data interpolates over NaNs in a matrix.
% call as function in=interp_missing_data(in,maxgap).  
% linear interp of the data in the columnwise direction
% maxgap is the biggest gap we allow to fill (default=5).  

if nargin<2
  maxgap=5;
end
[nrow,ncol]=size(in);

% first we replace all of the NaN occurences in order:
for gapsize=1:maxgap
  for k=1:gapsize
  tmp=find(isnan(in));
  tmp=tmp(tmp>=(1+k) & tmp<=(nrow*ncol-gapsize+k-1));
  in(tmp)=((gapsize-k+1)*in(tmp-k)+k*in(tmp-k+gapsize+1))/(gapsize+1);
%  tmp=find(isnan(in));
%  tmp=tmp(find(tmp>=gapsize & tmp<=(nrow*ncol-gapsize)));
  end
end
  
 
