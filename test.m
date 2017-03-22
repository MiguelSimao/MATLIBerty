clear; close all; clc;

instrreset;
liberty=Liberty('/dev/ttyUSB0');
%liberty.verbose = true;
liberty.connect;
liberty.stream;
% k=tic;
% previousTime=toc(k);
% currentTime=toc(k);
% timeElapsed=currentTime-previousTime;
% 
% while(currentTime<Inf)
%     
%     currentTime=toc(k);
%     timeElapsed=currentTime-previousTime;
%     
%     if(timeElapsed>0.01)
%         previousTime=currentTime;
%         x=liberty.data2(3:end,1)';
%         fprintf('%3.2f ',x); fprintf('\n');
%     end
% end
% 
% fclose(liberty);