# LowRankVortex.jl


This repository is a companion to the journal article [^1]: [Le Provost, Baptista, Marzouk, and Eldredge (2022) "A low-rank ensemble Kalman filter for elliptic observations," Proceedings of the Royal Society A, 478(2266), 20220182](https://doi.org/10.1098/rspa.2022.0182).

Link to the arXiv version: [Le Provost, Baptista, Marzouk, and Eldredge (2022), "A low-rank ensemble Kalman filter for elliptic observations," *arXiv preprint*, arXiv:2203.05120](https://arxiv.org/abs/2203.05120)

In this paper, we introduce a regularization of the ensemble Kalman filter for elliptic observation operators. Inverse problems with elliptic observations are highly compressible: low-dimensional projections of the observation strongly inform a low-dimensional subspace of the state space. We introduce the *low-rank ensemble Kalman filter (LREnKF)* that successively identifies  the low-dimensional informative subspace, performs the data assimilation in this subspace and lifts the result to the original space. We assess this filter on potential flow problems, where we seek to estimate the positions and strengths of collection of point vortices from spatially limited and noisy observations of the solution of a Poisson equation.



This repository contains the source code and Jupyter notebooks to reproduce the numerical experiments and Figures in Le Provost et al. [^1]

![](https://github.com/mleprovost/LowRankVortex.jl/raw/main/example2/setup_example2.png)

Estimation of the trajectories of the vortices with the LREnKF for $40$ ensemble members (see Section 2.b in Le Provost et al. [^1] for more details).

## Installation

This package works on Julia `1.6` and above. To install from the REPL, type
e.g.,
```julia
] add https://github.com/mleprovost/LowRankVortex.jl.git
```

Then, in any version, type
```julia
julia> using LowRankVortex
```

## Correspondence email
[mathieu.leprovost@liu.edu](mailto:mathieu.leprovost@liu.edu)

## References

[^1]: Le Provost, Baptista, Marzouk, and Eldredge (2022) "A low-rank ensemble Kalman filter for elliptic observations," Proceedings of the Royal Society A, 478(2266), 20220182, [rspa.2022.0182](https://doi.org/10.1098/rspa.2022.0182).

## Licence

See [LICENSE.md](https://github.com/mleprovost/LowRankVortex.jl/raw/main/LICENSE.md)
