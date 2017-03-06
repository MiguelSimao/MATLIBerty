classdef Liberty < handle
    %LIBERTY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        serial_port
        serial_obj
        message_size = 48 * 5 %48 bytes per sentence,
        timestamper = tic
    end
    
    
    properties (SetAccess = protected)
        data = zeros(8,1000)
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
                           'BytesAvailableFcnCount',this.message_size,...
                           'Terminator','CR/LF',...
                           'BytesAvailableFcn',@this.serialCallback,...
                           'InputBufferSize',1024);
            this.serial_obj = serial_obj;

        end
        function connect(this)
            % Connect device
            try
                fopen(this.serial_obj);
            catch err
                error(err.message)
            end
            this.isConnected = true;
            % Configure device
            fwrite(this.serial_obj,['F1' 13]); %binary mode
            fwrite(this.serial_obj,['O1,11,8,2,4,1' 13]); %output data list
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
            warning('Function not implemented (low priority).');
            %fwrite(this.serial_obj,3); % Ctrl+C, break
        end
        
        function close(this)
            % close connection
            stop(this);
            fclose(this.serial_obj);
        end
        function fclose(this)
            % overload fclose function
            fclose(this.serial_obj);
        end
        function serialCallback(this,serialObj,~)
            s = serialObj;
            
            sentence = [s.UserData ; ...
                        fread(s,s.BytesAvailableFcnCount)];
            %s.UserData has the remaining bytes of the previous cycle
            
            % Sentence size:
            l = numel(sentence);

            % Look for terminator:
            while l >= 48 % If more than one sample is in the sentence, read them all.
                          % Sample size is 25 bytes incl header and terminator.
                    
                % terminator = 0; % NUL
                % terminator = repmat(terminator,l,1);
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

                if pos + 1 < 42 % Incomplete message, read next sentence
                    sentence = sentence(pos+2:end);
                    s.UserData = sentence; % save rest
                    break;
                end

                % Set stream flag
                this.isStreaming = (output(4)==67); % byte 4 == 'C' during ocntinuous stream

                newsample = zeros(8,1);
                newsample(1) = round(toc(this.timestamper)*1000);
                newsample(2) = typecast(uint8(output(13:16)),'uint32');
                newsample(3:8) = typecast(uint8(output(17:40)),'single');

                % Circular Buffer
                this.data = [newsample this.data(:,1:end-1)];
                
                % fprintf('%.4f ',handles.Ldata(3:end,1)); fprintf('\n');
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

