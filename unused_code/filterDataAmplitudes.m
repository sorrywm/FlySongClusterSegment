function [out,mask,threshold,smoothedPeakLocations] = filterDataAmplitudes(...
    data,sigma,minLength,maxNumGaussians,replicates,maxNumPoints,minSeperation,threshold)

    if nargin < 2 || isempty(sigma)
        sigma = 40;
    end
    
    if nargin < 3 || isempty(minLength)
        minLength = 20;
    end

    if nargin < 4 || isempty(maxNumGaussians)
        maxNumGaussians = 2;
    end
    
    if nargin < 5 || isempty(replicates)
        replicates = 3;
    end
    
    if nargin < 6 || isempty(maxNumPoints)
        maxNumPoints = 10000;
    end
    
    if nargin < 7 || isempty(minSeperation)
        minSeperation = 100;
    end
    
    if nargin < 7 || isempty(minSeperation)
        minSeperation = 100;
    end
    
    
    
    %log of gaussian filter smoothed squared signal
    y = log10(gaussianfilterdata(data.^2,sigma));
    
    %find threshold and initial mask
    if nargin < 8 || isempty(threshold) || threshold < 0
        threshold = -9e99;
    end
    
    %gaussian mixture model for log(smoothed signal)
    obj = findBestGMM_AIC(y,maxNumGaussians,replicates,maxNumPoints);
    
    %identify max peak and min peak
    idx = argmax(obj.mu);
    minIdx = argmin(obj.mu);
    posts = posterior(obj,y);
    posts = posts(:,idx);
    
    %find mask and threshold
    mask = (posts >= .5 | y > obj.mu(idx)) & y > obj.mu(minIdx);
    new_threshold = min(y(mask));
    
    if new_threshold < threshold
        mask = y > threshold;
    else
        threshold = new_threshold;
    end
        
    %zero all connected components smaller than minLength
    CC = bwconncomp(mask);
    lengths = returnCellLengths(CC.PixelIdxList);
    idx = find(lengths < minLength);
    for i=1:length(idx)
        mask(CC.PixelIdxList{idx(i)}) = false;
    end
    
    
    %make masked data set
    out = data.*double(mask);
    
    
    %find maxima of masked data set
    smoothedPeakLocations = find(imregionalmax(y.*double(mask)) & mask);
    
    
    %eliminate all peaks spaced less than diffThreshold
    if minSeperation ~= -1
        
        d = diff(smoothedPeakLocations);
        a = d < minSeperation;
        while sum(a) > 0
            
            if sum(a) > 0
                CC = bwconncomp(a);
                for j=1:CC.NumObjects
                    b = [CC.PixelIdxList{j};CC.PixelIdxList{j}(end)+1];
                    c = smoothedPeakLocations(b);
                    minLocation = argmin(y(c));
                    smoothedPeakLocations(b(minLocation)) = -1;
                end
            end
            
            smoothedPeakLocations = smoothedPeakLocations(smoothedPeakLocations > 0);
            d = diff(smoothedPeakLocations);
            a = d < minSeperation;
            
        end
        
    end
    
    
    