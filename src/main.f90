program spinchain

!!load subroutines
use dependencies
!!load constants
use constants
!!load initial parameters
use parameters

implicit none

!!This program solves an XY spin chain problem. It diagonalizes the hamiltonian obtaining
!!for chains or networks of different geometries and distributions, and obtains its
!!eigenvectors and eigenvalues as well as evolves it dynamically with a defined set of
!!initial conditions. Properties such Fidelity, Entropy and Entanglement of Formation
!!can be computed by using the relevant subroutines
!a change

!NOTES:
! *1* all the comments marked with (E.I.) indicate that the process has been done this way for the
!     sake of efficiency of the program. I.e., due to the fact that we are working with wery large
!     Hilbert spaces, the subspaces and the factorials are calculated progressively in dependence
!     of the initial needs

!***************************************************!
!******************  VARIABLES *********************!
!***************************************************!

!integers

integer :: i,j,k,l,m,t,v,w   !loop dummies
integer :: ii,jj,kk,ll,mm    !more loop dummies
integer :: prev,next,last    !more fancy loop dummies
integer :: nit,Ninit,ex      !subroutine Permutations variables
integer :: len_branch
integer :: con_lim1
integer :: con_lim2
integer :: con_lim3
integer :: con_lim4
integer :: con_lim5
integer :: hub
integer :: hub_prima
integer :: hub_semi
integer :: vectors1ex = N    !Initially set to N, reallocate later if needed (E.I.)
integer :: vectors2ex = N    !Initially set to N, reallocate later if needed (E.I.)
integer :: vectors3ex = N    !Initially set to N, reallocate later if needed (E.I.)
integer :: vectorstotal      !Sum of all the vectors
integer :: info, lwork, liwork             !Info in lapack subroutines
integer, allocatable, dimension (:) :: iwork

!floats

real(kind=dbl) :: norm,normal,orto !normaliztion constant
real(kind=dbl) :: fidelity_e,prob  !fidelity

!complex


!vectors

integer, dimension(N) :: vec, test
integer, dimension(N+1) :: array

real(kind=dbl), dimension(N) :: Js = 0.0_dbl
real(kind=dbl), allocatable, dimension(:) :: eigvals
real(kind=dbl), allocatable, dimension(:) :: rwork
real(kind=dbl), allocatable, dimension(:) :: fidelity
real(kind=dbl), dimension(N) :: siteProb = 0.0_dbl


complex(kind=dbl), allocatable, dimension(:) :: work


!matrices

integer, allocatable, dimension(:,:) :: H1,H2,H3,HT !Hilbert subspaces matrices

real(kind=dbl), allocatable, dimension(:,:) :: hami, hami3 !Hamiltonian

complex(kind=dbl), allocatable, dimension(:,:) :: hami2 !other hamiltonians


character :: a,b,c,d
character(len=32) :: tmp,tmp1,tmp2
character(len=500) :: fmt1,fmt2,fmt3,fmt4 !format descriptors
character(len=32) :: class, subclass


integer,dimension(8) :: values !array with date

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! START PROGRAM AND WRITE OUTPUT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (output) then
    !retrieve date
    call date_and_time(VALUES=values)
    101 FORMAT (1X,59("*"))
    102 FORMAT (1X,16("*")," SPIN CHAIN PROGRAM OUTPUT ",16("*"))
    103 FORMAT (20X,I2,"/",I2.1,"/",I4,2X,I2,":",I2)
    104 FORMAT (1X,59("-"))
    open (unit=40,file='spinchain.out',status='replace')
    write(40,101)
    write(40,102)
    write(40,101)
    write(40,*) '           © Marta P. Estarellas, 27/07/2016              '
    write(40,*) '                   University of York                     '
    write(40,103) values(3),values(2),values(1),values(5),values(6)
    write(40,104)
    write(40,*)
endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! DEFINING THE DESIRED TYPE OF CHAIN !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!**********************************************
!this is done in the module called PARAMETERS
!you should ONLY modify that module to set the
!conditions and structure of the chain.
!**********************************************

write(*,*) '>> Defining System'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! INITIAL CHECKS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (linear) then
    if (ssh_a.or.ssh_b) then
        if (MOD(N-1,4)/=0) then
            STOP 'ERROR: for type (a) ssh chain N needs to be odd and N-1 needs to be divisible by 4.'
        endif
    endif

    if (abc) then
        if (MOD(N-3,4)/=0) then
            STOP 'ERROR: for type ABC chain N needs to be odd and N-3 needs to be divisible by 4.'
        endif
    endif

    if (kitaev) then
        if (MOD(N,2)/=0) then
            STOP 'ERROR: for a kitaev chain N needs to be even.'
        endif
    endif
endif

if (branched) then
    if (branches==3) then
        if (MOD((N-1),3)/=0) then
            STOP 'ERROR: Triple branched networks need to have EVEN number of sites and (N-1) needs to be divisible by 3.'
        endif
    endif

    if (branches==4) then
        if (MOD((N-1),4)/=0) then
            STOP 'ERROR: Four branched networks need to have ODD number of sites and (N-1) needs to be divisible by 4.'
        endif
    endif

    if (branches==5) then
        if (MOD((N-1),5)/=0) then
            STOP 'ERROR: Five branched networks need to have EVEN number of sites and (N-1) needs to be divisible by 5.'
        endif
    endif

    if (branches==6) then
        if (MOD((N-1),6)/=0) then
            STOP 'ERROR: Six branched networks need to have ODD number of sites and (N-1) needs to be divisible by 6.'
        endif
    endif
endif

write(*,*) '>> Initial checks'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! DEFINING BASIS VECTORS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!Calculate number of vectors for each excitation N!/exno!(N-exno)! subspace and the total number
!this is done progressively, sector by sector for sake of efficiency:

if (exno==1) then
    vectorstotal = vectors1ex+1
else if (exno==2) then
    vectors2ex = (N*(N-1)/2)
    vectorstotal = vectors1ex+vectors2ex+1
else if (exno==3) then
    vectors2ex = (N*(N-1)/2)
    vectors3ex = (N*(N-1)*(N-2)/6)
    vectorstotal = vectors1ex+vectors2ex+vectors3ex+1
end if

!Allocate matrices that will contain all the vectors:

allocate(H1(N,N))
allocate(H2(vectors2ex,N))
allocate(H3(vectors3ex,N))
allocate(HT(vectorstotal,N))

H1 = 0  !1ex subspace matrix
H2 = 0  !2ex subspace matrix
H3 = 0  !3ex subspace matrix
!... keep adding matrices
HT = 0  !total vectors

!Create the subsectors matrices through a recursive call to Permutations
!First subsector (including ground state - all spins down):

    do i=1,N
        do j=1,N
            if (i.eq.j) then
                H1(i,j)=1
            endif
        enddo
    enddo

    HT(2:,:) = H1

!Second subsector (two excitations):

if (exno>1) then
    nit=1
    Ninit=1
    vec=0
    k=1
    ex=2
    call permutations(ex,nit,vec,N,Ninit,H2,vectors2ex,k)

    HT(vectors1ex+2:,:) = H2
endif

!Third subsector (three excitations):

if (exno>2) then
    nit=1
    Ninit=1
    vec=0
    k=1
    ex=3
    call permutations(ex,nit,vec,N,Ninit,H3,vectors3ex,k)

    HT(vectors1ex+vectors2ex+2:,:) = H3
endif

!**(NOTE: Add extra subsectors in the same fashion if needed)**

!Stdout vectors martix
if (output) then
201 FORMAT ('|',I2,'> -->' I2)
202 FORMAT (/A)
203 FORMAT (/)
    write(40,FMT=202) 'BASIS VECTORS:'
    do i=1,vectorstotal
        write(40,*) i,'-->',(HT(i,j),j=1,N)
    enddo
endif

write(*,*) '>> Basis vectors defined'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! INITIAL STATE NORMALIZATION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

write(*,*) '>> Defining initial injection'
!TO-DO
!write(*,*) '   These are your vectors and its numbering:'
!    do i=1,vectorstotal
!        write(*,*), i,'-->',(HT(i,j),j=1,N)
!    enddo
!write(*,*) '   A superposition of how many vectors do you want to start with?'
!
!read(*,'(i5.2)') numI
!
!write(*,*) '   Which of these vectors do you want to use to set the initial state?'
!write(*,*) '   NOTE: this allows a superposition of max. 4 states'
!write(*,*) '   INPUT EXAMPLE: 1+2+6+10'
!
!205 FORMAT (i5.2,A)
!a='+'
!i=1
!do while (a=='+')
!    write(tmp,'(i2)') i
!    b='"initialVec'//trim(adjustl(tmp))
!
!    read(*,FMT=205) b,a
!    print*, tmp
!    i=i+1
!enddo

!normalization factor dependenig
!on the number of initial injections

norm=(1._dbl/sqrt(float(numI)))

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! DEFINE CONNECTIVITY !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (linear) then
    len_branch = 0
    hub = 0
    con_lim1 = N
    con_lim2 = 0
    con_lim3 = 0
endif

!!!!TO BE GENERALIZED
!
!len_branch = ((2*(N - 1)/branches)+1)
!do i=1,branches-1
!    con_lim(i) = con_lim + 1


!if (crossed_three) then
!    len_branch = ((2*(N - 1)/3)+1)
!    hub = ((len_branch-1)/2) + 1
!    con_lim1 = len_branch
!    con_lim2 = con_lim1 + 1
!endif
!
!if (crossed_four) then
!    len_branch = ((2*(N - 1)/4)+1)
!    hub = ((len_branch-1)/2) + 1
!    con_lim1 = len_branch
!    con_lim2 = con_lim1 + 1
!    con_lim3 = con_lim2 + (len_branch-2)
!endif
!
!if (crossed_five) then
!    len_branch = ((2*(N - 1)/5)+1)
!    hub = ((len_branch-1)/2) + 1
!    con_lim1 = len_branch
!    con_lim2 = con_lim1 + 1
!    con_lim3 = con_lim2 + (len_branch-2)
!    con_lim4 = con_lim3 + (len_branch-2)
!endif
!
!if (crossed_six) then
!    len_branch = ((2*(N - 1)/6)+1)
!    hub = ((len_branch-1)/2) + 1
!    con_lim1 = len_branch
!    con_lim2 = con_lim1 + 1
!    con_lim3 = con_lim2 + (len_branch-2)
!    con_lim4 = con_lim3 + (len_branch-2)
!    con_lim5 = con_lim4 + (len_branch-2)
!endif


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! DEFINE COUPLING PATTERN !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call couplings(Js)

!Stdout coupling pattern
301 FORMAT ("(spin",I3,")-(spin",I3,") -->",F6.2)
if (output) then
    write(40,FMT=202) 'COUPLING PATTERN:'
    do i=1,N-1
        write(40,FMT=301) i, i+1, Js(i)
    enddo
endif

write(*,*) '>> Coupling pattern defined'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! BUILD HAMILTONIAN IN THE SPIN BASIS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

allocate(hami(vectorstotal,vectorstotal))

if (linear) then
    call build_hamiltonian_linear(HT,Js,N,vectorstotal,hami)
else if (crossed) then
    call build_hamiltonian_crosses(HT,Js,N,vectorstotal,hami,branches)
endif

!Stdout Hamiltonian
if (output) then
    write(40,FMT=202) 'HAMILTONIAN MATRIX:'
    do i=1,vectorstotal
        write(40,*) (hami(i,j),j=1,vectorstotal)
    enddo
endif

write(*,*) '>> Hamiltonian Build'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! TRANSLATE THE HAMILTONIAN IN THE MJ BASIS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!




!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! ADD PERTURBATION FACTORS TO THE HAMILTONIAN !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! DIAGONALIZATION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

allocate(hami2(vectorstotal,vectorstotal))
allocate(hami3(vectorstotal,vectorstotal))
allocate(eigvals(vectorstotal))
allocate(rwork((2*(vectorstotal**2))+5*vectorstotal+1))
allocate(work((vectorstotal**2)+2*vectorstotal))
liwork=5*vectorstotal+3
allocate(iwork(liwork))


hami2=cmplx(0.0_dbl, 0.0_dbl, kind=dbl)
hami3=0
do i=1,vectorstotal
    do j=1,vectorstotal
        hami2(i,j)=(hami(i,j))
    enddo
enddo

! ZHEEV computes all eigenvalues and, optionally, eigenvectors of a complex Hermitian
! matrix
if (files) then
open(unit=89,file='hami.data',status='unknown')
do i=1,vectorstotal
write(89,*) (hami(i,j),j=1,vectorstotal)
enddo
close(89)
endif
!call zheev('V','U',vectorstotal,hami2,size(hami2,1),eigvals,work,size(work,1),rwork,info)
call zheevd('V','U',vectorstotal,hami2,size(hami2,1),eigvals,work,size(work,1),rwork,size(rwork,1),iwork,liwork,info)
if(info/=0) stop 'ERROR in ZHEEV diagonalization'


!check normalisation eigenvectors
do i=1,vectorstotal
    normal=0.
    do j=1,vectorstotal
        normal=normal+abs(hami2(i,j))**2
    enddo
    if (abs(1.-normal)>=error) then
        print*, 'ERROR: your eigenvectors are not well normalized'
        STOP
    endif
enddo

!check eigenvectors orthogonality
do v=1,vectorstotal
    do i=1,vectorstotal
        orto=0.
        do j=1,vectorstotal
                orto=orto+hami2(i,j)*hami2(v,j)
        enddo
        if ((orto>error).and.(v/=i)) then
            print*, 'ERROR: your eigenvectors are not orthogonal'
            STOP
        endif
    enddo
enddo

!!Stdout Eigenvalues
if (output) then

    !set formats
    write(tmp,'(i3.1)') vectorstotal
    fmt1='(1X,i3.1,1X,'//tmp//'("(",f7.3,f7.3,")"))'
    fmt2='(6X,'

    do i=1,vectorstotal
        write(tmp,'(i3.1)') i
        fmt2=trim(fmt2)//'"Eigenvector'//trim(adjustl(tmp))//':",3X,'
    enddo

    fmt2=trim(fmt2)//")"

    !Eigenvalues
    write(40,FMT=202) 'EIGENVALUES:'
    do i=1,vectorstotal
        if (eigvals(i)==0._dbl) cycle
        write(40,*) eigvals(i)
    enddo

    !Eigenvectors
    write(40,FMT=202) 'EIGENVECTORS'

    write(40,fmt2)
    do i=1,vectorstotal
        write(40,fmt1) i ,(hami2(i,:))
    enddo
endif

!Save data in files
if (files) then
open (unit=41,file='coefficients.data',status='unknown')
open (unit=42,file='probabilities.data',status='unknown')
open (unit=43,file='eigenvalues.data',status='unknown')


do i=1,vectorstotal
    write(41,*) real(hami2(i,:))
    write(42,*) (abs(dconjg(hami2(i,:))*(hami2(i,:))))
    write(43,*) eigvals(i)
enddo


close(41)
close(42)
close(43)
endif

write(*,*) '>> Hamiltonian Diagonalization'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! DYNAMICS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call injection_dynamics(HT,hami2,eigvals,vectorstotal,initialVec1,norm)

!siteProb=0
!do i=1,vectorstotal
!    do k=1,N
!        if (HT(i,k)==1) then
!            siteProb(k) = siteProb(k) + fidelity(i)
!        endif
!    enddo
!enddo

write(*,*) '>> Dynamics'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! ENTANGLEMENT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! ENTROPY !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! PLOTTING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!Graphics
if (graphical) then
    !Writes in a file data needed for plots
    open(unit=46,file='graphical.data',status='unknown')
    501 FORMAT ("GRAPHICAL=",A)
    write(46,501) "T"
    write(tmp,'(i5.2)') vectorstotal
    601 FORMAT ("VECTORS=",A)
    write(46,601) adjustl(trim(tmp))
    write(tmp,'(f6.2)') totaltime
    701 FORMAT ("TOTALTIME=",A)
    write(46,701) adjustl(trim(tmp))
    write(tmp,'(i5.2)') initialVec1
    801 FORMAT ("INITIALVEC=",A)
    write(46,801) adjustl(trim(tmp))
!call system ("sed -i.bak '/0.0000000000000000/d' ./eigenvalues.data")
!call system ('python eigenvalues.py '//trim(tmp)) !plot energy spectrum
!call system ('python dynamics.py '//trim(tmp)//trim(tmp1)) !plot dynamics

endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! FREE SPACE AND CLOSE FILES AND CLEAN !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (output) then
    close(unit=40)
    close(unit=46)
endif

deallocate(H1)
deallocate(H2)
deallocate(H3)
deallocate(HT)
deallocate(hami)
deallocate(hami2)
deallocate(eigvals)
deallocate(rwork)
deallocate(work)

end program



