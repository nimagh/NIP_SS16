% Goal: Gaussian Process Classification - GPC
clc; clear; close all
rng('default');
maxiter = 1000;

%% setup test Data points
n1 = 100; n2 = 50;

S1 = eye(2); S2 = [1,0.95;0.95,1];
m1 = [0.75, 0]; m2 = [-0.75, 0];

x1 = mvnrnd(m1,S1,n1);
x2 = mvnrnd(m2,S2,n2);

x = [x1;x2]; y = [-ones(n1,1); ones(n2,1)];
x_test = x;
plot(x1(:,1), x1(:,2), 'b+'); hold on;
plot(x2(:,1), x2(:,2), 'r+');
axis([-4 4 -4 4]);

%% predictive gaussian parameter finding (probit likelihood)
% based on algo 3.1 page 65 GPML book

sigmaf = 1; l = 1; sigman = 1;
K = get_kernel(x,x,sigmaf,l,sigman);
K = nearestSPD(K);
K = K + eps*eye(size(K));
f = zeros(size(y));

old_log_marg = -Inf; 
iter = 0; 
%while old_log_marg - New_objective > tol && it<maxit %newton iterations
for iter = 1:maxiter
    npf = normpdf(f); cpyf = normcdf(y.*f);
    
    %lp = log(cpyf);
    dlp = y.*npf./cpyf;%3.16
    d2lp = -npf.^2./cpyf.^2 - y.*f.*npf./cpyf;% 3.16
    
    W = -d2lp; sW = sqrt(W);
    B = eye(size(x,1))+sW.*K.*sW;%B=I+sqrt(W)*K*sqrt(W)
    %B = make_PD(B);
    B = nearestSPD(B);
    L = chol(B,'lower');
    b = W.*f + dlp; % 3.18 part 1
    a = b - sW.*(L'\(L\(sW.*K*b)));
    f = K*a;
    new_log_marg = -0.5 * a'*f ...
                + sum(log(normcdf(y.*f)))...
                - sum(log(diag(L)));
    if abs(new_log_marg - old_log_marg) < 1e-3 % need to adapt step sizes
        fprintf('FOUND! %f at %d iteration!',abs(new_log_marg - old_log_marg),iter)
        break
    else
        old_log_marg = new_log_marg;
    end
end  

%% Binary classification with  approximated Laplace GPC
% algo 3.2 GPML
fhat = f;

p = [1, 0.1];

fun = @(p) -(-0.5*fhat'*(get_kernel(x,x,p(1),p(2),0)\fhat) ...
    + sum(log(normcdf(y.*fhat)))...
    -0.5*log(det(eye(size(x,1))+...
    sqrt(normpdf(fhat).^2./normcdf(y.*fhat).^2 + y.*fhat.*normpdf(fhat)./normcdf(y.*fhat))...
    .*get_kernel(x,x,p(1),p(2),0).*...
    sqrt(normpdf(fhat).^2./normcdf(y.*fhat).^2 + y.*fhat.*normpdf(fhat)./normcdf(y.*fhat)))));
p = fminsearch(fun,p);

sigmaf=p(1); l=p(2);

npf = normpdf(fhat); cpyf = normcdf(y.*fhat);
    
lp = log(cpyf);
dlp = y.*npf./cpyf;%3.16
d2lp = -npf.^2./cpyf.^2 - y.*fhat.*npf./cpyf;% 3.16

W = -d2lp; sW = sqrt(W);
B = eye(size(x,1))+sW.*K.*sW;%B=I+sqrt(W)*K*sqrt(W)
B = make_PD(B);
B = nearestSPD(B);
L = chol(B,'lower');

K_s = get_kernel(x_test, x, sigmaf, l, sigman);
K_ss = get_kernel(x_test, x_test, sigmaf, l, sigman);

fs = K_s'*dlp;
v = L\(sW.*K_s);

y_test_var = diag(K_ss - v'*v);% uncertainty
y_test_mean = normcdf(real(fs./sqrt(1+y_test_var)));% best prediction

plot(x(y_test_mean>=0.5,1), x(y_test_mean>=0.5,2), 'rO'); hold on;
plot(x(y_test_mean<0.5,1), x(y_test_mean<0.5,2), 'bO'); hold on;
title('Gaussian Process Classification')

%% computation of the covariance function
function K = get_kernel(X1,X2,sigmaf,l,sigman)
k = @(x1,x2,sigmaf,l,sigman) (sigmaf^2)*exp(-(1/(2*l^2))*(x1-x2)*(x1-x2)') + (sigman^2);
K = zeros(size(X1,1),size(X2,1));
for i = 1:size(X1,1)
    for j = 1:size(X2,1)
        if i==j;K(i,j) = k(X1(i,:),X2(j,:),sigmaf,l,sigman);
        else;K(i,j) = k(X1(i,:),X2(j,:),sigmaf,l,0);end
    end
end
end
