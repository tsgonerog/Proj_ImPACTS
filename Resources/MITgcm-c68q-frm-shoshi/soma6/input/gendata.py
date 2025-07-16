import numpy as np
from numpy import cos, pi, tanh, arccos

Ho = 2400  # depth of ocean - Hshelf (m)
Hshelf = 100
phi = 0.1
a = 6.3781e6
b = 1.25e6
nx = 210   # gridpoints in x
ny = 174    # gridpoints in y
xo = -16.5     # origin in x,y for ocean domain
yo = 21.5    # (i.e. southwestern corner of ocean domain)
xc = 0
yc = 35
dx = 0.1666666666666667     # grid spacing in x (degrees longitude)
dy = 0.1666666666666667     # grid spacing in y (degrees latitude)
xeast  = xo + (nx-12)*dx   # eastern extent of ocean domain
ynorth = yo + (ny-12)*dy   # northern extent of ocean domain

def haversine_np(lon1, lat1, lon2, lat2):
    lon1, lat1, lon2, lat2 = map(np.radians, [lon1, lat1, lon2, lat2])
    
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    
    aa = np.sin(dlat/2.0)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2.0)**2
    
    c = 2 * np.arcsin(np.sqrt(aa))
    d = a * c
    return d

# Soma bottom

x = np.linspace(xo, xeast, nx)
y = np.linspace(yo, ynorth, ny)
Y, X = np.meshgrid(y, x, indexing='ij')

d = haversine_np(X, Y, xc, yc)
hh = 1 - np.square(d/b)
h = (-Hshelf - Ho/2*(1+tanh(hh/phi)))*np.heaviside(hh+0.4,0)

# save as single-precision (float32) with big-endian byte ordering

h.astype('>f4').tofile('bathy.bin')

# ocean domain extends from (xo,yo) to (xeast,ynorth)
# (i.e. the ocean spans nx-2, ny-2 grid cells)
# out-of-box-config: xo=0, yo=15, dx=dy=1 deg, ocean extent (0E,15N)-(60E,75N)
# model domain includes a land cell surrounding the ocean domain
# The full model domain cell centers are located at:
#    XC(:,1) = -0.5, +0.5, ..., +60.5 (degrees longitiude)
#    YC(1,:) = 14.5, 15.5, ..., 75.5 (degrees latitude)
# and full model domain cell corners are located at:
#    XG(:,1) = -1,  0, ..., 60 [, 61] (degrees longitiude)
#    YG(1,:) = 14, 15, ..., 75 [, 76] (degrees latitude)
# where the last value in brackets is not included 
# in the MITgcm grid variables XG,YG (but is in variables Xp1,Yp1)
# and reflects the eastern and northern edge of the model domain respectively.
# See section 2.11.4 of the MITgcm users manual.

# Zonal wind-stress

tau0 = 0.1
xi = 0.5
x = np.linspace(xo-dx, xeast, nx)
y = np.linspace(yo-dy, ynorth, ny) + dy/2
Y, X = np.meshgrid(y, x, indexing='ij')     # zonal wind-stress on (XG,YC) points
delY = a*(Y-yc)/180*pi
tau = (1-xi*delY/b) * tau0 * np.exp(-np.square(delY/b)) * cos(pi*delY/b)  # ny-2 accounts for walls at N,S boundaries



tau.astype('>f4').tofile('windx_cosy.bin')

