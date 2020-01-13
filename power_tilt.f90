    !This module provides the initial power spectra, parameterized as an expansion in ln k
    !
    ! ln P_s = ln A_s + (n_s -1)*ln(k/k_0_scalar) + n_{run}/2 * ln(k/k_0_scalar)^2 + n_{runrun}/6 * ln(k/k_0_scalar)^3
    !
    ! so if n_{run} = 0, n_{runrun}=0
    !
    ! P_s = A_s (k/k_0_scalar)^(n_s-1)
    !
    !for the scalar spectrum, when n_s=an(in) is the in'th spectral index. k_0_scalar
    !is a pivot scale, fixed here to 0.05/Mpc (change it below as desired or via .ini file).
    !
    !The tensor spectrum has three different supported parameterizations giving
    !
    ! ln P_t = ln A_t + n_t*ln(k/k_0_tensor) + n_{t,run}/2 * ln(k/k_0_tensor)^2
    !
    ! tensor_parameterization==tensor_param_indeptilt (=1) (default, same as CAMB pre-April 2014)
    !
    ! A_t = r A_s
    !
    ! tensor_parameterization==tensor_param_rpivot (=2)
    !
    ! A_t = r P_s(k_0_tensor)
    !
    ! tensor_parameterization==tensor_param_AT (=3)
    !
    ! A_t =  tensor_amp
    !
    !The absolute normalization of the Cls is unimportant here, but the relative ratio
    !of the tensor and scalar Cls generated with this module will be correct for general models
    !
    !December 2003 - changed default tensor pivot to 0.05 (consistent with CMBFAST 4.5)
    !April 2014 added different tensor parameterizations, running of running and running of tensors

    module InitialPower
    use Precision
    use MpiUtils, only : MpiStop
    use classes
    implicit none

    private

    integer, parameter, public :: tensor_param_indeptilt=1,  tensor_param_rpivot = 2, tensor_param_AT = 3

    Type, extends(TInitialPower) :: TInitialPowerLaw
        integer :: tensor_parameterization = tensor_param_indeptilt
        !For the default implementation return power spectra based on spectral indices
        real(dl) :: ns = 1._dl !scalar spectral indices
        real(dl) :: nrun = 0._dl !running of spectral index
        real(dl) :: nrunrun  = 0._dl !running of spectral index
        real(dl) :: nt  = 0._dl !tensor spectral indices
        real(dl) :: ntrun  = 0._dl !tensor spectral index running
        real(dl) :: r  = 0._dl !ratio of scalar to tensor initial power spectrum amplitudes
        real(dl) :: pivot_scalar = 0.05_dl !pivot scales in Mpc^{-1}
        real(dl) :: pivot_tensor = 0.05_dl
        real(dl) :: As = 1._dl
        real(dl) :: At = 1._dl !A_T at k_0_tensor if tensor_parameterization==tensor_param_AT
    contains
    procedure :: PythonClass => TInitialPowerLaw_PythonClass
    procedure :: ScalarPower => TInitialPowerLaw_ScalarPower
    procedure :: TensorPower => TInitialPowerLaw_TensorPower
    procedure :: ReadParams => TInitialPowerLaw_ReadParams
    procedure :: Effective_ns => TInitalPowerLaw_Effective_ns

    end Type TInitialPowerLaw

    !Make things visible as neccessary...

    public TInitialPowerLaw
    contains

    function TInitialPowerLaw_PythonClass(this)
    class(TInitialPowerLaw) :: this
    character(LEN=:), allocatable :: TInitialPowerLaw_PythonClass
    TInitialPowerLaw_PythonClass = 'InitialPowerLaw'
    end function TInitialPowerLaw_PythonClass

    function TInitialPowerLaw_ScalarPower(this, k)
    class(TInitialPowerLaw) :: this
    real(dl), intent(in) :: k
    real(dl) TInitialPowerLaw_ScalarPower
    real(dl) lnrat
    !ScalarPower = const for scale invariant spectrum
    !The normalization is defined so that for adiabatic perturbations the gradient of the 3-Ricci
    !scalar on co-moving hypersurfaces receives power
    ! < |D_a R^{(3)}|^2 > = int dk/k 16 k^6/S^6 (1-3K/k^2)^2 ScalarPower(k)
    !In other words ScalarPower is the power spectrum of the conserved curvature perturbation given by
    !-chi = \Phi + 2/3*\Omega^{-1} \frac{H^{-1}\Phi' - \Psi}{1+w}
    !(w=p/\rho), so < |\chi(x)|^2 > = \int dk/k ScalarPower(k).
    !Near the end of inflation chi is equal to 3/2 Psi.
    !Here nu^2 = (k^2 + curv)/|curv|

    !This power spectrum is also used for isocurvature modes where
    !< |\Delta(x)|^2 > = \int dk/k ScalarPower(k)
    !For the isocurvture velocity mode ScalarPower is the power in the neutrino heat flux.


    lnrat = log(k/this%pivot_scalar)
    TInitialPowerLaw_ScalarPower = this%As * exp(lnrat * (this%ns - 1 + &
        &             lnrat * (this%nrun / 2 + this%nrunrun / 6 * lnrat)))

    end function TInitialPowerLaw_ScalarPower


    function TInitialPowerLaw_TensorPower(this,k)
    use constants
    class(TInitialPowerLaw) :: this
    !TensorPower= const for scale invariant spectrum
    !The normalization is defined so that
    ! < h_{ij}(x) h^{ij}(x) > = \sum_nu nu /(nu^2-1) (nu^2-4)/nu^2 TensorPower(k)
    !for a closed model
    ! < h_{ij}(x) h^{ij}(x) > = int d nu /(nu^2+1) (nu^2+4)/nu^2 TensorPower(k)
    !for an open model
    !Here nu^2 = (k^2 + 3*curv)/|curv|
    real(dl), intent(in) :: k
    real(dl) TInitialPowerLaw_TensorPower
    real(dl), parameter :: PiByTwo=const_pi/2._dl
    real(dl) lnrat, k_dep

    lnrat = log(k/this%pivot_tensor)
    k_dep = exp(lnrat*(this%nt + this%ntrun/2*lnrat))
    if (this%tensor_parameterization==tensor_param_indeptilt) then
        TInitialPowerLaw_TensorPower = this%r*this%As*k_dep
    else if (this%tensor_parameterization==tensor_param_rpivot) then
        TInitialPowerLaw_TensorPower = this%r*this%ScalarPower(this%pivot_tensor) * k_dep
    else if (this%tensor_parameterization==tensor_param_At) then
        TInitialPowerLaw_TensorPower = this%At * k_dep
    end if
    if (this%curv < 0) TInitialPowerLaw_TensorPower= &
        TInitialPowerLaw_TensorPower*tanh(PiByTwo*sqrt(-k**2/this%curv-3))
    end function TInitialPowerLaw_TensorPower

    function CompatKey(Ini, name)
    class(TIniFile), intent(in) :: Ini
    character(LEN=*), intent(in) :: name
    character(LEN=:), allocatable :: CompatKey
    !Allow backwards compatibility with old .ini files where initial power parameters were arrays

    if (Ini%HasKey(name//'(1)')) then
        CompatKey = name//'(1)'
        if (Ini%HasKey(name)) call MpiStop('Must have one of '//trim(name)//' or '//trim(name)//'(1)')
    else
        CompatKey = name
    end if
    end function CompatKey

    subroutine TInitialPowerLaw_ReadParams(this, Ini, WantTensors)
    use IniObjects
    class(TInitialPowerLaw) :: this
    class(TIniFile), intent(in) :: Ini
    logical, intent(in) :: WantTensors

    call Ini%Read('pivot_scalar', this%pivot_scalar)
    call Ini%Read('pivot_tensor', this%pivot_tensor)
    if (Ini%Read_Int('initial_power_num', 1) /= 1) call MpiStop('initial_power_num>1 no longer supported')
    if (WantTensors) then
        this%tensor_parameterization =  Ini%Read_Int('tensor_parameterization', tensor_param_indeptilt)
        if (this%tensor_parameterization < tensor_param_indeptilt .or. &
            &   this%tensor_parameterization > tensor_param_AT) &
            &   call MpiStop('InitialPower: unknown tensor_parameterization')
    end if
    this%r = 1
    this%ns = Ini%Read_Double(CompatKey(Ini,'scalar_spectral_index'))
    call Ini%Read(CompatKey(Ini,'scalar_nrun'), this%nrun)
    call Ini%Read(CompatKey(Ini,'scalar_nrunrun'), this%nrunrun)

    if (WantTensors) then
        this%nt = Ini%Read_Double(CompatKey(Ini,'tensor_spectral_index'))
        call Ini%Read(CompatKey(Ini,'tensor_nrun'),this%ntrun)
        if (this%tensor_parameterization == tensor_param_AT) then
            this%At = Ini%Read_Double(CompatKey(Ini,'tensor_amp'))
        else
            this%r = Ini%Read_Double(CompatKey(Ini,'initial_ratio'))
        end if
    end if

    call Ini%Read(CompatKey(Ini,'scalar_amp'),this%As)
    !Always need this as may want to set tensor amplitude even if scalars not computed

    end subroutine TInitialPowerLaw_ReadParams

    function TInitalPowerLaw_Effective_ns(this)
    class(TInitialPowerLaw) :: this
    real(dl) :: TInitalPowerLaw_Effective_ns

    TInitalPowerLaw_Effective_ns = this%ns

    end function TInitalPowerLaw_Effective_ns

    end module InitialPower
