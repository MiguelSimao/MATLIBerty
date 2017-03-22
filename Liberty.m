classdef Liberty < handle
    %LIBERTY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hemisphere_zenith = [0,-1,0]
    end
    
    properties (SetAccess = protected)
        port
        serial_obj
        sentence_size
        outputlist = {'pos_xyz'}
                  
        verbose = true
        
        frames_per_cycle = 10
        
        data1 = zeros(3,1000)
        data2 = zeros(3,1000)
        timestamper = tic
        
        isStreaming = false
        isConnected = false
        distortionState
        
        
    end
    properties (SetAccess = private)
        incompleteSamples = 0
        header = uint8('LY')
        outputdefs = struct('ascii_space','0',...
                          'ascii_cr','1',...
                          'pos_xyz','2',...
                          'pos_xyz_extended','3',...
                          'ori_euler','4',...
                          'ori_euler_extended','5',...
                          'dcm','6',...
                          'ori_quat','7',...
                          'timestamp','8',...
                          'frame_count','9',...
                          'stylus_flag','10',...
                          'distortion_level','11',...
                          'external_sync','12')
        
        outputsize = struct('ascii_space',1,...
                          'ascii_cr',1,...
                          'pos_xyz',3*4,...
                          'pos_xyz_extended',3*4,...
                          'ori_euler',3*4,...
                          'ori_euler_extended',3*4,...
                          'dcm',3*3*4,...
                          'ori_quat',4*4,...
                          'timestamp',12,...
                          'frame_count',12,...
                          'stylus_flag',4,...
                          'distortion_level',4,...
                          'external_sync',4)
    end
    
    methods
        % Constructor method:
        function this = Liberty(port)
            % port is a string. ex: 'COM14' or '/dev/rfcomm1'

            serial_obj = serial(port);
            set(serial_obj,'BaudRate',115200,...
                           'BytesAvailableFcnMode','byte',...
                           'BytesAvailableFcnCount',1,...
                           'Terminator','CR/LF',...
                           'BytesAvailableFcn',@this.serialCallback,...
                           'InputBufferSize',2048);
                       
            this.serial_obj = serial_obj;
            this.port = port;

        end
        function connect(this)
            
            % Configure serial connection:
            this.serial_obj.BytesAvailableFcnCount = this.frames_per_cycle * this.sentence_size;
            % Connect device:
            try
                fopen(this.serial_obj);
            catch err
                error(err.message)
            end
            this.isConnected = true;
            
            % Configure device:
            fwrite(this.serial_obj,['F1' 13]); %binary mode
            fwrite(this.serial_obj,['H*,0,-1,0' 13]); % set hemisphere zenith (-Y)
            fwrite(this.serial_obj,['R3' 13]); %rate 120 Hz
            fwrite(this.serial_obj,['U1' 13]); %metric units
            % Set outputs:
            defs = this.outputdefs;
            defssize = this.outputsize;
            
            outputlist = this.outputlist;
            strlist = cellfun(@(var)defs.(var),outputlist,'UniformOutput',false);
            
            fwrite(this.serial_obj,'O*');
            fwrite(this.serial_obj,[sprintf(',%s',strlist{:}) 13]);
            
            pause(0.5);
            
            this.sentence_size = 8 + sum(cellfun(@(x)defssize.(x),outputlist));
        end
        
        function stream(this)
            this.timestamper = tic;
            
            % start stream
            fwrite(this.serial_obj,['C' 13]);
        end
        
        function stop(this)
            % stop stream
            fwrite(this.serial_obj,'P'); % Ctrl+C, break
            this.isStreaming = false;
        end
        
        function close(this)
            % close connection
            stop(this);
            fclose(this.serial_obj);
        end
        function fclose(this)
            stop(this);
            % overload fclose function
            fclose(this.serial_obj);
        end
        function fopen(this)
            connect(this);
        end
        function serialCallback(this,serialObj,~)
            s = serialObj;
            
            sentence = [s.UserData ; ...
                        fread(s,s.BytesAvailableFcnCount)];
            %s.UserData has the remaining bytes of the previous cycle
            
            terminator = [13 10];
            
            % Find message headers:
            pos = strfind(sentence,this.header);
            
            % Divide incoming message into a cell (array of strings):
            output = cell(numel(pos),1);
            for i=1:numel(pos)-1
                output{i} = sentence(pos(i):pos(i+1)-1);
            end
            output{end} = sentence(pos(end):end);
            
            % Get size of each sentence:
            actual_size = cellfun(@numel,output);
            % expected_size = 0;
            
            % Save last sentence if incomplete
            if actual_size(end) < this.sentence_size
                s.UserData = output{end};
                output = output(1:end-1);
            end
            
            % Find and remove incomplete messages:
            this.incompleteSamples = this.incompleteSamples + sum(actual_size ~= this.sentence_size);
            output = output(actual_size == this.sentence_size);
            
            output = cell2mat(output);
            
            % Set stream flag
            this.isStreaming = (output(end,4)==67); % byte 4 == 'C' during continuous stream
            
            stationNumber = output(:,3);
            output = output(:,9:end);
            
            
            % FOR TESTING ONLY: XYZ
            output = output(:,9:20)';
            n = size(output,2); % number of messages
            newsamples = typecast(uint8(output(:)),'single');
            newsamples = reshape(newsamples,[],n)';
%             newsamples = typecast(uint8(output(17:44)),'single');
%             newsamples = zeros(3,1);
%             newsamples(1) = round(toc(this.timestamper)*1000);
%             newsamples(2) = typecast(uint8(output(13:16)),'uint32');
%             newsamples(3:9) = typecast(uint8(output(17:44)),'single');

            % Circular Buffer
            if stationNumber == 1
                this.data1 = [newsamples this.data1(:,1:end-1)];
            elseif stationNumber == 2
                this.data2 = [newsamples this.data2(:,1:end-1)];
            end

%             sentence = sentence(pos+2:end);
% 
%             l = numel(sentence);
%             s.UserData = sentence;
% 
%             % Store unread data
%             s.UserData = sentence;
% 
%             % Set stream flag:
%             this.isStreaming = true;
% 
%             % Set distortion state:
%             this.distortionState = typecast(uint8(output(9:12)),'uint32');

            %end
        end
    end
    
end

