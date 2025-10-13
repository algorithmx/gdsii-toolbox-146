function nume = numel(glib)
%function nume = numel(glib)
%
% Returns the number of elements in a library.
%
% glib :   an object of the gds_library class
% nume :   the number of elements in the library
%

% Ulf Griesmann, NIST, September 2013

    if isempty(glib.st)
        nume = 0;
    else
        % sum element numbers for each structure
        % Use a more compatible approach for Octave
        nume = 0;
        for i = 1:length(glib.st)
            if ~isempty(glib.st{i})
                % Use built-in numel on the elements field directly
                nume = nume + numel(glib.st{i}.el);
            end
        end
    end

end
