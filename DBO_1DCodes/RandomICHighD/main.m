% Code to solve a high dimensional random initial condition case
% Written by: Prerna Patil
% Date: 13th Feb 2020

clc
clear
close all
clear global

% Delare other variables
LW = 'linewidth';
RGB1 = [0 113 188 ]/norm([0 113 188 ]);
RGB2 = [216 82 24 ]/norm([216 82 24 ]);

global nu
% Problem set up
% Initialization
N    = 2;                % # of the basis {u_i}
Ns   = 128;              % the number of collocation points in physical space
Nr   = 640;            % the number of collocation points in random space
L    = 2*pi;             % the length of the interval [0,2*pi]
rDim = 5;               % dimension of random space
dom  = [0, L];
nu   = 0.05;
sigma= 0.5;              % Variance of the random perturbations
x    = L*(0:Ns-1)'/Ns;   % collocation points
wp   = L/Ns*ones(length(x),1);
t0   = 0;
tf   = 10;               % final time
dt   = 0.001;

% Load the collocation points in the random space obtained using MePCM code
% for Anchored ANOVA
fname = sprintf('ColPnts_d%d-%d.dat',rDim,Nr);
xr = load(fname);
fname = sprintf('ColWgts_d%d-%d.dat',rDim,Nr);
wr = load(fname);
wr = wr/sum(wr);
xr = xr/sqrt(sum(xr(:,1).*wr.*xr(:,1)));
% Set up the initial conditions
% Initial condition:
u0 = 0.5*(exp(cos(2*x))-1.5).*sin(3*x+2*pi*0.37);
nTimeStep = ceil((tf)/dt);
bu = [];
bSigma= zeros(rDim, rDim);
% Set up the perturbations
for i=1:rDim
    bu = [bu, sin(i*x-t0)/sqrt(pi)];
    bSigma(i,i) = sigma/i;
end
% Take the first N modes
bu    = bu(:,1:N);
bSigma= bSigma(1:N, 1:N);
bubar = u0;
bY = xr(:,1:N);
% Time loop
n=1;
DBO = true;
cov_dbo = zeros(N,nTimeStep);
while(n <= (nTimeStep-1))
    % Compute DBO solutions:
    t1 = dt * (n-1)+t0;
    [rhs_bubar1, rhs_bu1, rhs_bY1, rhs_bSigma1] = compute_rhs_dbo(bubar, bu, bY, bSigma, wr, wp);
    
    t2 = dt * (n-1/2)+t0;
    bubar2  = bubar  + dt*rhs_bubar1/2.0;
    bu2     = bu     + dt*rhs_bu1/2.0;
    bY2     = bY     + dt*rhs_bY1/2.0;
    bSigma2	= bSigma + dt*rhs_bSigma1/2.0;
    [rhs_bubar2, rhs_bu2, rhs_bY2, rhs_bSigma2] = compute_rhs_dbo(bubar2, bu2, bY2, bSigma2, wr, wp);
    
    t3 = dt * n+t0;
    bubar3 	= bubar  - dt*rhs_bubar1  + 2.0*dt*rhs_bubar2;
    bu3		= bu     - dt*rhs_bu1     + 2.0*dt*rhs_bu2;
    bY3		= bY     - dt*rhs_bY1     + 2.0*dt*rhs_bY2;
    bSigma3 = bSigma - dt*rhs_bSigma1 + 2.0*dt*rhs_bSigma2;
    [rhs_bubar3, rhs_bu3, rhs_bY3, rhs_bSigma3] = compute_rhs_dbo(bubar3 , bu3, bY3, bSigma3, wr, wp);
    
    nbubar 	= bubar  + dt*(rhs_bubar1 + 4.0*rhs_bubar2  +rhs_bubar3)/6.0;
    nbu		= bu     + dt*(rhs_bu1    + 4.0*rhs_bu2     +rhs_bu3)/6.0;
    nbY		= bY     + dt*(rhs_bY1    + 4.0*rhs_bY2     +rhs_bY3)/6.0;
    nbSigma = bSigma + dt*(rhs_bSigma1+ 4.0*rhs_bSigma2 +rhs_bSigma3)/6.0;
    
    % Enforce zero mean condition
    for i=1:N
        nbY(:,i) = nbY(:,i) - sum(nbY(:,i).*wr);
    end
    
    % Enforce gram schmidt condition on bY and bu
    nbY(:,1) = nbY(:,1)/sum(nbY(:,1).*nbY(:,1).*wr);
    for i=2:N
        tempY = nbY(:,i);
        tempU = nbu(:,i);
        for j=1:i-1
            tempY = tempY - sum( nbY(:,i).*nbY(:,j).*wr )/sum( nbY(:,j).*nbY(:,j).*wr )*nbY(:,j);
            tempU = tempU - sum( nbu(:,i).*nbu(:,j).*wp )/sum( nbu(:,j).*nbu(:,j).*wp )*nbu(:,j);
        end
        tempY = tempY/ sum(tempY.*tempY.*wr);
        nbY(:,i) = tempY;
        tempU = tempU/ sum(tempU.*tempU.*wp);
        nbu(:,i) = tempU;
    end
    cov_dbo(:,n) = eig(nbSigma*nbSigma');
    
    % DBO update
    bY     = nbY;
    bubar  = nbubar;
    bu     = nbu;
    bSigma = nbSigma;
    
    if mod(n,100)==0
        drawnow
        disp(['t=' num2str(t0+n*dt) ' is being processed'])
    end
    n=n+1; % necessary for while statement
    
end

% Plot the eigenvalues
Time = (1:n)*dt;
figure(1)
for i=1:N
    semilogy(Time(1:1:end), cov_dbo(i,1:1:end), '--','color',RGB1, LW, 1.5);
    hold on
    semilogy(Time(1:999:end), cov_dbo(i,1:999:end), 'x','color',RGB1, LW, 1.5);
end
xlabel('Time');
ylabel('Eigenvalues')
set(gca, 'FontSize', 16, 'Fontname', 'Times New Roman');
fname = sprintf('Eigenvalues');
saveas(gcf,fname,'epsc')
saveas(gcf,fname,'fig')

% Plot total variance
figure(2)
TV = sum(cov_dbo);
semilogy(Time, TV, '--','color',RGB2, LW, 1.5);
hold on
semilogy(Time(1:999:end), TV(1:999:end), 'x','color',RGB2, LW, 1.5);
xlabel('Time');
ylabel('Total variance');
set(gca, 'FontSize', 16, 'Fontname', 'Times New Roman');
fname = sprintf('TV');
saveas(gcf,fname,'epsc')
saveas(gcf,fname,'fig')