function [R, dRdU, dRdw, z] = MDOF_NLHYST_HBRESFUN(Uw, Pars, L, pA, MESH, M, C, K, Fl, h, Nt, varargin)
%MDOF_NLHYST_HBRESFUN
%
%
  if length(varargin)>=1
    nldofs = varargin{1};
  else 
    nldofs = 1:size(L,1);
  end
  Nhc = sum(h==0) + 2*sum(h~=0);
  Nph = size(L, 1);  % Physical DoFs
  Nd = size(L, 2);   % Projected DoFs
  
  [E, dEdw] = HARMONICSTIFFNESS(M, C, K, Uw(end), h);
  D1 = HARMONICSTIFFNESS(0, 1, 0, Uw(end), h);
  
  t   = linspace(0, 2*pi, Nt+1);  t(end) = [];
  ut  = zeros(Nt, Nph);
  udt = zeros(Nt, Nph);
  
  Uh = reshape(Uw(1:end-1), Nd, Nhc)';
  ut(:, nldofs)  = TIMESERIES_DERIV(Nt, h, Uh*L(nldofs,:)', 0);  % Disp Time-series of just the non-linear dofs
  udt(:, nldofs) = TIMESERIES_DERIV(Nt, h, Uh*L(nldofs,:)', 1);  % Vel Time-series of just the non-linear dofs
  ut = ut';
  udt = udt';
  
  % Fourier-Galerkin Bases
  cst = TIMESERIES_DERIV(Nt, h, eye(Nhc), 0);
  sct = TIMESERIES_DERIV(Nt, h, D1, 0);
  
  % Time-Marching for the Hysteretic Non-linearities
  ft = zeros(Nph, Nt);
  dfdxt = zeros(Nph, Nph, Nt);
  dfdxdt = zeros(Nph, Nph, Nt);
%  z = repmat(MESH.z, 1, 1, Nt);  % Maybe we don't need this?
  
  zprev = MESH.z;
  
  it = 0;

  % while max(abs(ftprev(:)-ft(:))) > 1e-8 || it ==0
  % while it<2
  while max(abs(zprev(:)-MESH.z(:))) > 1e-8 || it == 0
    ftprev = ft;
    zprev = MESH.z;
    for i = 1:Nt
% [ft(:,i), z(:, :, i), dfdxt(:, :, i), dfdxdt(:, :, i)] = CONTACTEVAL(MESH, ut(:,i), z(:, :, i), udt(:, i), Pars, pA);
      [ft(:,i), MESH.z, dfdxt(:, :, i), dfdxdt(:, :, i)] = CONTACTEVAL(MESH, ut(:,i), ...
								       MESH.z, udt(:, i), Pars, pA);
    end
    fprintf('%d %e\n', it, max(max(abs(MESH.z-zprev))));
    it = it+1;

    % fprintf('%d %e\n', it, max(abs(ftprev(:)-ft(:))));
  end
  % End of Time marching
  
  % Nonlinear forces in frequency domain
  Fnl = zeros(Nhc, Nph);
  Fnl(:, nldofs) = GETFOURIERCOEFF(h, ft(nldofs, :)');
  Fnl = reshape(Fnl', Nph*Nhc, 1);
  
  % Nonlinear jacobians in frequency domain
  Jnl = zeros(Nhc*Nph, Nhc*Nph);

  % Fulla loops
  for ni=1:length(nldofs)
    for nj=1:length(nldofs)
      fid = nldofs(ni);
      xid = nldofs(nj);
      
      if nnz(dfdxt(fid, xid, :)) > 0 || nnz(dfdxt(fid, xid, :)) > 0
      % if any(dfdxt(fid, xid, :)) || any(dfdxt(fid, xid, :))
        Jnl(fid:Nph:end, xid:Nph:end) = GETFOURIERCOEFF(h, reshape(dfdxt(fid, xid, :), Nt, 1).*cst + reshape(dfdxdt(fid, xid, :), Nt, 1).*sct);
      end
    end
  end

  % Apply Projection "L"
  if Nph>Nd  % L represents some reduction, so the following will work
    for h=1:Nhc
      Fnl((h-1)*Nd+(1:Nd)) = L'*Fnl((h-1)*Nph+(1:Nph));
      
      Jnl((h-1)*Nd+(1:Nd), :) = L'*Jnl((h-1)*Nph+(1:Nph), :);
      Jnl(:, (h-1)*Nd+(1:Nd)) = Jnl(:, (h-1)*Nph+(1:Nph))*L;
    end

    Fnl = Fnl(1:Nd*Nhc);
    Jnl = Jnl(1:Nd*Nhc, 1:Nd*Nhc);
  end

  % Residue
  R = E*Uw(1:end-1) + Fnl - Fl;
  dRdU = E + Jnl;
  dRdw = dEdw*Uw(1:end-1);

  z = MESH.z;
end