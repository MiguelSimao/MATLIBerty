classdef Liberty < handle
    %LIBERTY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hemisphere_zenith = [0,-1,0]
    end
    
    properties (SetAccess = protected)
        port
        serial_obj
        sentence_size = 52
        frames_per_cycle = 10
        data1 = zeros(9,1000)
        data2 = zeros(9,1000)
        timestamper = tic
        
        isStreaming = false
        isConnected = false
        distortionState
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
            
            % Configure device
            fwrite(this.serial_obj,['F1' 13]); %binary mode
            % fwrite(this.serial_obj,['O*,11,8,2,4,1' 13]); %output data list
            fwrite(this.serial_obj,['O*,11,8,2,7,1' 13]); %output data list
            fwrite(this.serial_obj,['H*,0,-1,0' 13]); % set hemisphere zenith (-Y)
            fwrite(this.serial_obj,['R3' 13]); %rate 120 Hz
            fwrite(this.serial_obj,['U1' 13]); %metric units
            pause(0.5);
        end
        
        function stream(this)
            % start stream
            fwrite(this.serial_obj,['C' 13]);
    
            this.timestamper = tic;
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
            
            % Sentence size:
            l = numel(sentence);

            % Look for terminator:
            while l >= this.sentence_size
                          % If more than one sample is in the sentence, read them all.
                          % Sample size is 25 bytes incl header and terminator.
   
                terminator = [13 10];
                terminator = repmat(terminator,l,1);

                CR = (terminator(:,1) == sentence);
                LF = (terminator(:,2) == sentence);

                LF = [LF(2:end); LF(1)]; %shift positions of LF by -1

                pos = find(and(CR,LF),1); %position of the first terminator byte
                %pos is also the number of bytes since the beggining of the sentence
                %counting with the first terminator byte

                if isempty(pos)
                    break; end

                output = sentence(1:pos-1);
                
                % Deal with incomplete messages, read next
                if pos + 1 < this.sentence_size-8
                    sentence = sentence(pos+2:end);
                    s.UserData = sentence; % save leftovers
                    break;
                end

                % Set stream flag
                this.isStreaming = (output(4)==67); % byte 4 == 'C' during continuous stream
                stationNumber = sentence(3);
                newsample = zeros(9,1);
                newsample(1) = round(toc(this.timestamper)*1000);
                newsample(2) = typecast(uint8(output(13:16)),'uint32');
                newsample(3:9) = typecast(uint8(output(17:44)),'single');
                
                % Circular Buffer
                if stationNumber == 1
                    this.data1 = [newsample this.data1(:,1:end-1)];
                elseif stationNumber == 2
                    this.data2 = [newsample this.data2(:,1:end-1)];
                end
                
                sentence = sentence(pos+2:end);

                l = numel(sentence);
                s.UserData = sentence;

                % Store unread data
                s.UserData = sentence;

                % Set stream flag:
                this.isStreaming = true;
                
                % Set distortion state:
                this.distortionState = typecast(uint8(output(9:12)),'uint32');

            end
        end
    end
    
end

