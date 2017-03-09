# MATLIBerty
--------------
Communications wrapper for Polhemus Liberty.

# USAGE:
liberty = Liberty(port_name)


liberty.connect

liberty.stream



% get most recent sample from station 1

data = liberty.data1(:,1);

% or, from station 2, if available:

data = liberty.data2(:,2); 


% stop stream:

liberty.stop;

% make port available:

liberty.close;
