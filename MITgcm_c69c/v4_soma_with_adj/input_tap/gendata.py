import numpy as np
from numpy import cos, pi, tanh, arccos

Ho = 3400      # depth of ocean - Hshelf (m)
Hshelf = 100   # shelf depth
phi = 0.02     # controls slope steepness (slope width as fraction of domain)
nx = 62        # gridpoints in x
ny = 62        # gridpoints in y
xo = 0         # origin in x,y for ocean domain
yo = 15        # (i.e. southwestern corner of ocean domain)
xc = 30        # domain center in  x
yc = 45        # and in y 
dx = 1         # grid spacing in x (degrees longitude)
dy = 1         # grid spacing in y (degrees latitude)
xeast  = xo + (nx-2)*dx   # eastern extent of ocean domain
ynorth = yo + (ny-2)*dy   # northern extent of ocean domain

# Soma bottom

x = np.linspace(xo, xeast, nx)
y = np.linspace(yo, ynorth, ny)
Y, X = np.meshgrid(y, x, indexing='ij')

d = np.linalg.norm(np.array([X-xc,Y-yc]),axis=0)
hh = 1 - np.square(d/28)
h = (-Hshelf - Ho/2*(1+tanh(hh/phi)))*np.heaviside(hh+0.14,0)

# save as single-precision (float32) with big-endian byte ordering

h.astype('>f4').tofile('bathy.bin')



# Zonal wind-stress
tau0 = 0.1
xi = 0.5
x = np.linspace(xo-dx, xeast, nx)
y = np.linspace(yo-dy, ynorth, ny) + dy/2
Y, X = np.meshgrid(y, x, indexing='ij')     # zonal wind-stress on (XG,YC) points
delY = (Y-yc)/30
tau = (1-xi*delY) * tau0 * np.exp(-np.square(delY)) * cos(pi*delY)

tau.astype('>f4').tofile('wind.bin')

# Restoring temperature (function of y only,
# from Tmax at southern edge to Tmin at northern edge)
Tmax = 25
Tmin = 0
Trest = (Tmax-Tmin)/(ny-2)/dy * (ynorth-Y) + Tmin # located and computed at YC points
Trest.astype('>f4').tofile('SST_relax.bin')

# Restoring salinity (function of y only,
# from Smax at southern edge to Smin at northern edge)
Smax = 36
Smin = 35
Srest = (Smax-Smin)/(ny-2)/dy * (ynorth-Y) + Smin # located and computed at YC points
Srest.astype('>f4').tofile('SSS_relax.bin')
