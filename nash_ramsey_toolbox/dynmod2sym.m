% (c) Copyright Andrew T. Levin 2004
% Note: this program and all associated subroutines may be used freely, 
% subject to the restriction that this source should be acknowledged 
% together with citation of the following paper:  
%    "Optimal Monetary Policy with Endogenous Capital Accumulation" 
%     Andrew T. Levin and J. David Lopez-Salido
%     Manuscript, Federal Reserve Board, 2004.

% This program reads a Dynare .MOD file and creates symbolic version of model
% Assumes that infilename has already been set, without .MOD extension
% Set ramsey_flag > 0 when generating ramsey model; 0 otherwise

% rule_delim contains string used in identifying policy rule equations
%  (This string must occur in the comment just prior to each rule equation.)
% If ramsey_flag > 0, the list of equations generated by this program 
% does not include any policy rules, because these will be created by
% the get_ramsey program.

rule_delim = 'Policy Rule';

% Endogenous and exogenous variable delimiters  
%   (These delimiters control whether variables in a dynare var statement
%   are classified as endogenous or exogenous; the delimiter remains 
%   in effect until a different delimiter is reached.)

endog_delim = 'Endogenous variables';
exog_delim = 'Exogenous variables';

% Names of period utility and welfare variables
% If ramsey_flag = 1, these are not included in list of endogenous variables, 
% and their definitions are not included in the list of equations.

Util_vname = 'Util';
Welf_vname = 'Welf';

% Set initial values of various variables

modelflag = 0;
parflag = 0;
ruleqflag = 0;
shkflag = 0;
utilflag = 0;
welfflag = 0;
varflag = 0;
endogflag = 0;
exogflag = 0;
initflag = 0;
iline = 1;
nempty = 0;
ncomments = 0;
eqmat = '';
eqlist = '';
parmat = '';
shkmat = '';
endovarmat = '';
exovarmat = '';
parmstring = '';
debugflag = 0;
modline = 0;
endinitline = 0;
endmodline = 0;

rulecount = 0;        % # rules found so far
rulestartline = [];   % first line of each rule equation
rulestopline = [];    % last line of each rule equation
ruleqmat = '';        % String array of rule equations (saved just in case)

% Start processing blocks of lines from rawfile
rawfile = textread([infilename,'.mod'],'%s', ...
                    'delimiter','\n','whitespace','','bufsize',40000);
while iline <= length(rawfile),
  rawline = char(rawfile(iline));
  if debugflag,
    disp([num2str(iline),' ',rawline]);
  end;
  
% Empty lines get skipped
  if isempty(deblank(rawline)),
    nempty = nempty + 1;

% Skip comments after checking for the relevant delimiters
  elseif strncmp(strtok(rawline),'//',2),
    if ~isempty(strfind(rawline,endog_delim)),
      endogflag = 1;
      exogflag = 0;
    elseif ~isempty(strfind(rawline,exog_delim)),
      endogflag = 0;
      exogflag = 1;
    elseif ramsey_flag & ~isempty(strfind(rawline,rule_delim)),
      rulecount = rulecount + 1;
      disp(rawline);
      ruleqflag = 1;
      rulestartline = [rulestartline (iline-1)];
    end;        
    ncomments = ncomments + 1;

% Start of initialization block
  elseif strncmpi(rawline,'initval;',8),
      initflag = 1;

% End of initialization block
% (No need to parse anything after this)
  elseif initflag & strncmpi(rawline,'end;',4),
    initflag = 0;
    endinitline = iline;
    iline = length(rawfile);

% Start of model block
  elseif strncmpi(rawline,'model;',6),
      modelflag = 1;
      modline = iline;
      
% End of model block
  elseif modelflag & strncmpi(rawline,'end;',4),
    modelflag = 0;
    endmodline = iline;

% Individual model equation
  elseif modelflag,

  % Read in the entire equation, which may span multiple lines, but
  % must be delimited by a semicolon at the end.  
  
    lhs_string = '';
    rhs_string = '';
    while isempty(strfind(rawline,'=')) & isempty(strfind(rawline,';')),
      lhs_string = [lhs_string,rawline];
      iline = iline + 1;
      rawline = char(rawfile(iline));
    end;
    
  % If equal sign is present, then parse equation into lhs and rhs.

    if strfind(rawline,'='),
      eqloc = strfind(rawline,'=');
      lhs_string = [lhs_string, rawline(1:(eqloc-1))];
      rest = rawline((eqloc+1):length(rawline));
      while isempty(strfind(rest,';')),
        rhs_string = [rhs_string, rest];
        iline = iline + 1;
        rest = char(rawfile(iline));
      end;
      semiloc = strfind(rest,';');
      rhs_string = [rhs_string, rest(1:(semiloc-1))];
      [lhs_token,lhs_rest] = strtok(lhs_string);
      
  % If ramsey_flag, then distinguish policy rule and definitions 
  % of utility and welfare from other equations (which are saved
  % in eqmat).

      if ramsey_flag & (ruleqflag > 0),
        rule_string = [lhs_string,' = ',rhs_string,';'];
        ruleqmat = strvcat(ruleqmat,rule_string);
        ruleqflag = 0;
        rulestopline = [rulestopline, iline];
      elseif ramsey_flag & strcmpi(lhs_token,Util_vname),
        Util_string = [lhs_string,' = ',rhs_string,';'];
        utilflag = -1;
      elseif ramsey_flag & strcmpi(lhs_token,Welf_vname),
        Welf_string = [lhs_string,' = ',rhs_string,';'];
        welfflag = -1;
      else,
        ieq=size(eqmat,1)+1;
        eqlist = [eqlist, ' eq',num2str(ieq)];
        eqstring = ['eq',num2str(ieq),' = ',lhs_string,' - (',rhs_string,');'];
        eqmat = strvcat(eqmat,eqstring);
      end;

% If no equality sign present, then just save entire equation in eqmat
% (except for policy rule when ramsey_flag = 1)

    else,
      semiloc = strfind(rawline,';');
      rhs_string = [rhs_string, rawline(1:(semiloc-1))];
      if ramsey_flag & (ruleqflag > 0),
        rule_string = [lhs_string,rhs_string,';'];
        ruleqmat = strvcat(ruleqmat,rule_string);
        ruleqflag = 0;
        rulestopline = [rulestopline, iline];
      else,
        ieq=size(eqmat,1)+1;
        eqlist = [eqlist, ' eq',num2str(ieq)];
        eqstring = ['eq',num2str(ieq),' = ',lhs_string,rhs_string,';'];
        eqmat = strvcat(eqmat,eqstring);
      end;
    end;
          
% Parameters  
  elseif parflag | strncmpi(rawline,'parameters ',11),
    if ~parflag,
      rawline = rawline(12:length(rawline));
    end;
    [parname,rest] = strtok(rawline,' ,;');
    parmat = strvcat(parmat,parname);
    while ~isempty(rest),
      [parname,rest] = strtok(rest,' ,;');
      parmat = strvcat(parmat,parname);
    end;
    if isempty(strfind(rawline,';')),
      parflag = 1;
    else,
      parflag = 0;
    end;
    
% Shocks
  elseif shkflag | strncmpi(rawline,'varexo ',7),
    if ~shkflag,
      rawline = rawline(8:length(rawline));
    end;
    [shkname,rest] = strtok(rawline,' ,;');
    shkmat = strvcat(shkmat,shkname);
    while ~isempty(rest),
      [shkname,rest] = strtok(rest,' ,;');
      shkmat = strvcat(shkmat,shkname);
    end;
    if isempty(strfind(rawline,';')),
      shkflag = 1;
    else,
      shkflag = 0;
    end;

% Variables  
  elseif varflag | strncmpi(rawline,'var ',4),
    if endogflag==0 & exogflag==0,
      endogflag = 1;
      if ramsey_flag,
        disp('Warning: commment with endogenous or exogenous delimiter');
        disp('should precede the first var statement in the model file;'); 
        disp('otherwise, variables are assumed to be endogenous.');
      end;
    end;
    if ~varflag,
      rawline = rawline(5:length(rawline));
    end;
    [varname,rest] = strtok(rawline,' ,;');
    
    tmpvarmat = varname;
    while ~isempty(rest),
      [varname,rest] = strtok(rest,' ,;');
      tmpvarmat = strvcat(tmpvarmat,varname);
    end;
    if exogflag,
      exovarmat = strvcat(exovarmat,tmpvarmat);
    else,
      endovarmat = strvcat(endovarmat,tmpvarmat);
    end;
    if isempty(strfind(rawline,';')),
      varflag = 1;
    else,
      varflag = 0;
    end;
  end;
  
% Increment line counter and go to top of loop
  iline = iline + 1;
end;  

% If ramsey_flag = 1, then check for presence of utility and welfare,
% and remove these from the list of endogenous variables.  Also
% check whether policy rule has been declared.

if ramsey_flag,
  if utilflag >= 0,
    disp('Warning:  no period utility definition found in model');
  end;
  if welfflag >= 0,
    disp('Warning:  no welfare definition found in model');
  end;
  iutil = strmatch(Util_vname,endovarmat,'exact');
  iwelf = strmatch(Welf_vname,endovarmat,'exact');
  if ~length(iutil) | ~length(iwelf),
    error('Either utility or welfare not declared in endogenous variable list');
  end;
  endovec = setdiff(1:size(endovarmat,1), [iutil iwelf]);
  endovarmat = endovarmat(endovec,:);
  if rulecount == 0,
    disp('Warning:  no policy rule(s) declared in model');
  else,
    disp(['Note: ',num2str(rulecount),' policy rules declared in model file']);
    if (length(rulestartline) ~= rulecount) | (length(rulestopline) ~= rulecount),
      error('Error: policy rule found but not terminated');
    end;
  end;
end;
  
% Create cell-arrays for parameters, variables, and shocks 
%  (sorted in alphabetical order, ignoring case)

npars = size(parmat,1);
nshks = size(shkmat,1);
nendog = size(endovarmat,1);
nexog = size(exovarmat,1);
nvars = nendog + nexog;

parcmat = sorticell(cellstr(parmat));
shkcmat = sorticell(cellstr(shkmat));
endocmat = sorticell(cellstr(endovarmat));
exocmat = sorticell(cellstr(exovarmat));
if nexog,
  varcmat = sorticell(cellstr(strvcat(endovarmat,exovarmat)));
else,
  varcmat = endocmat;
end;

% Find indices of endogenous variables in list of all variables

endo_index = zeros(nendog,1);
for iv = 1:nendog,
  vname = char(endocmat(iv));
  endo_index(iv) = strmatch(vname,varcmat,'exact');
end;

% If ramsey_flag, then add utility and welfare definitions 
% to the end of the equation array.  

if ramsey_flag,
  eqmat = strvcat(eqmat,Util_string,Welf_string);
end;

% Now loop over all equations, using the tokenize function 
% to modify equation string, where _0, _L# and _F# denote 
% contemporaneous values, lags, and leads, respectively, 
% and adding double-underscores to the parameter names 
% occuring in each equation; this function also determines 
% the maximum lag & lead of each variable.

neqs = size(eqmat,1);
var_incid = cell(nvars, neqs);
shk_incid = zeros(nshks, neqs);

alleqmat = '';
behav_eqvec = [];
maxvlags = zeros(neqs,nvars);
maxvleads = zeros(neqs,nvars);
maxeqlags = zeros(neqs,1);
maxeqleads = zeros(neqs,1);

for ieq = 1:neqs,
  [ieqstring,ieq_varincid,maxeqvlags,maxeqvleads,ieq_shkincid] ...
     = tokenize(eqmat(ieq,:),varcmat,shkcmat,parcmat);
  var_incid(:,ieq) = ieq_varincid;
  shk_incid(:,ieq) = ieq_shkincid;
  maxvlags(ieq,:) = maxeqvlags;
  maxvleads(ieq,:) = maxeqvleads;
  maxeqlags(ieq) = max(maxeqvlags(endo_index));
  maxeqleads(ieq) = max(maxeqvleads(endo_index));
  
% If equation involves endogenous variables, then add its index
% to list of behavioral equations 
  if max(~cellfun('isempty',ieq_varincid(endo_index))),
    behav_eqvec = [behav_eqvec, ieq];
  end;

% Finally, save modified equation in string array,
% and add double-underscore to cell array of parameter names.

  alleqmat = strvcat(alleqmat, ieqstring);
end;

parcmat = strcat(parcmat,'__');

% If ramsey_flag, then remove definitions of utility and welfare 
% from list of behavioral equations.

if ramsey_flag,
  behav_eqvec = setdiff(behav_eqvec, [neqs-1 neqs]);
end;    
nbehaveqs = length(behav_eqvec);

% Classify variables into groups based on leads/lags

mmaxvlags = max(maxvlags);
mmaxvleads = max(maxvleads);

idstatic = find(mmaxvlags==0 & mmaxvleads==0);
idinert = find(mmaxvlags > 0 & mmaxvleads==0);
idcombo = find(mmaxvlags > 0 & mmaxvleads > 0);
idforwd = find(mmaxvlags==0  & mmaxvleads > 0);
altorder = [idstatic, idinert, idcombo, idforwd];
valtmat = varcmat(altorder);

% Create cell arrays of all variables (including lags/leads)
%    jacvmat = alphabetical for each lag/lead
%    hesvmat = alternate ordering for each lag/lead

jacvmat = {};
hesvmat = {};

maxlag = max(mmaxvlags);
for ilag = 1:maxlag,
  icmat = varcmat(find(ilag <= mmaxvlags));
  jacvmat = [jacvmat; strcat(icmat,['_L',num2str(ilag)])];
  aicmat = valtmat(find(ilag <= mmaxvlags(altorder)));
  hesvmat = [hesvmat; strcat(aicmat,['_L',num2str(ilag)])];
end;

jacvmat = [jacvmat; strcat(varcmat,'_0')];
hesvmat = [hesvmat; strcat(valtmat,'_0')];

maxlead = max(mmaxvleads);
for ilead = 1:maxlead,
  icmat = varcmat(find(ilead <= mmaxvleads));
  jacvmat  = [jacvmat; strcat(icmat,['_F',num2str(ilead)])];
  aicmat = valtmat(find(ilead <= mmaxvleads(altorder)));
  hesvmat = [hesvmat; strcat(aicmat,['_F',num2str(ilead)])];
end;

jacvmat = [jacvmat; shkcmat];
hesvmat = [hesvmat; shkcmat];

% Declare all parameters and variables as symbols 
% and then create symbolic equations and variable lists

parstring = cell2string(parcmat,' ');
varstring = cell2string(varcmat,'_0 ');
shkstring = cell2string(shkcmat,' ');
jacvstring = cell2string(jacvmat,' ');
hesvstring = cell2string(hesvmat,' ');

eval(['syms ',parstring,';']);
eval(['syms ',jacvstring,';']);
if ramsey_flag,
  eval(['syms ',Util_vname,' ',Welf_vname,';']);
end;

alleqns = cell2string(deblank(cellstr(alleqmat)),' ');
eval(alleqns);
eval(['eqns = [',eqlist,'];']);

eval(['parlist = [',parstring,'];']);
eval(['varlist = [',varstring,'];']);
eval(['jacvlist = [',jacvstring,'];']);
eval(['hesvlist = [',hesvstring,'];']);
eval(['shklist = [',shkstring,'];']);
