function [history h0] = mymkirf2(dr_,ys_,nperiods,shock,addss,order,stochss,init)

%  dr_ structure returned by dynare (AR form for the model)
%  lgy_ vector of variable names, returned by dynare
%  lgx_ vector of innovation names, returned by dynare
%  nperiods number of periods for IRFs
%  shock  vector to be used to generated irfs
%  order selects order of approximation
%  stochss is indicator for initial point
%   =1 starts from stochastic steady state
%   otherwise start from the non-stochastic steady state

if nargin<8
    init = 0*ys_;
end

if stochss
     history = getpath(dr_,ys_,5000,0*shock,order);
     h0 = history(:,end);
     history = getpath(dr_,ys_,nperiods,shock,order,h0);
     history = history - repmat(h0,1,nperiods+1);   
else
    history = getpath(dr_,ys_,nperiods,shock,order,init);
    h0 = 0*history(:,1);
end

if (addss~=0)
    
    history = history(:,2:end)+repmat(ys_(dr_.order_var),1,nperiods);
    
else
    % don't add ss if addss is set to 0;
    history = history(:,2:end);
    
end
         


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBROUTINES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function history = getpath(dr_,ys_,nperiods,shock,order,h0)

nvars = size(dr_.ghx,1);
nshocks = size(dr_.ghu,2);
statevar_pos = (dr_.nstatic +1):(nvars-dr_.nfwrd);
%statevar_pos = (dr_.nstatic +1):(dr_.nstatic+size(dr_.ghx,2));

% if (max(size(shock)) > nshocks) | (max(size(shock))<1) 
%     error('erroneous shock vector as argument')
% end
% 
% if ( size(shock,1)<size(shock,2) )
%     shock = shock';
% end


history = zeros(nvars,nperiods+1);
shock_length = size(shock,1);

for i = 2:nperiods+1 
    if i-1 <= shock_length
        history(:,i) = dr_.ghx*history(statevar_pos,i-1) + dr_.ghu*shock(i-1,:)';
    else 
        history(:,i) = dr_.ghx*history(statevar_pos,i-1);
    end;
end
   


if order>1
     history2 = zeros(nvars,nperiods+1);
     if nargin > 5
         history2(:,1) = h0;
     end
     for i = 2:nperiods+1
         if i-1 <= shock_length
           history2(:,i) = 0.5*dr_.ghs2 + dr_.ghx*history2(statevar_pos,i-1) + dr_.ghu*shock(i-1,:)' + ... 
                     0.5*dr_.ghxx*kron(history(statevar_pos,i-1),history(statevar_pos,i-1)) + ...
                     0.5*dr_.ghuu*kron(shock(i-1,:)',shock(i-1,:)') + ...
                     dr_.ghxu*kron(history(statevar_pos,i-1),shock(i-1,:)');
         else
         history2(:,i) = 0.5*dr_.ghs2 + dr_.ghx*history2(statevar_pos,i-1) + ... 
                         0.5*dr_.ghxx*kron(history(statevar_pos,i-1),history(statevar_pos,i-1));
         end;
     end
     history = history2;
 end


