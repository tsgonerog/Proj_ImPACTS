import numpy as np
from numpy import cos, pi, tanh, arccos

Ho = 2400  # depth of ocean - Hshelf (m)
Hshelf = 100
phi = 0.1
a = 6.3781e6
b = 1.85e6
nx = 62   # gridpoints in x
ny = 62    # gridpoints in y
xo = 0     # origin in x,y for ocean domain
yo = 15    # (i.e. southwestern corner of ocean domain)
xc = 30
yc = 45
dx = 1     # grid spacing in x (degrees longitude)
dy = 1     # grid spacing in y (degrees latitude)
xeast  = xo + (nx-2)*dx   # eastern extent of ocean domain
ynorth = yo + (ny-2)*dy   # northern extent of ocean domain

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


# Restoring temperature (function of y only,
# from Tmax at southern edge to Tmin at northern edge)
Tmax = 30
Tmin = 0
Trest = (Tmax-Tmin)/(ny-2)/dy * (ynorth-Y) + Tmin # located and computed at YC points
Trest.astype('>f4').tofile('SST_relax.bin')


# Temperature field

t_prof = np.array([20., 19.977, 19.9515, 19.923, 19.8915, 19.857, 19.818, 19.775, \
        19.7275, 19.675, 19.6165, 19.552, 19.48, 19.401, 19.313, 19.2155, \
        19.1075, 18.9875, 18.855, 18.7085, 18.546, 18.3665, 18.1675, 17.947, \
        17.703, 17.4335, 17.135, 16.8045, 16.4395, 16.035, 15.588, 15.094, \
        14.547, 13.943, 13.2745, 12.536, 11.7195, 10.817, 9.8195, 8.7175]).reshape(1,1,-1)

theta = np.tile(t_prof.transpose(),(1,ny,nx))


theta.astype('>f4').tofile('temp.bin')



# Salinity field

s_prof = np.array([34., 34.0037, 34.0078, 34.0123, 34.0174, 34.0229, 34.0291, 34.036, \
        34.0436, 34.052, 34.0614, 34.0717, 34.0832, 34.0958, 34.1099, \
        34.1255, 34.1428, 34.162, 34.1832, 34.2066, 34.2326, 34.2614, \
        34.2932, 34.3285, 34.3675, 34.4106, 34.4584, 34.5113, 34.5697, \
        34.6344, 34.7059, 34.785, 34.8725, 34.9691, 35.0761, 35.1942, \
        35.3249, 35.4693, 35.6289, 35.8052]).reshape(1,1,-1)

s = np.tile(s_prof.transpose(),(1,ny,nx))

s.astype('>f4').tofile('salt.bin')
