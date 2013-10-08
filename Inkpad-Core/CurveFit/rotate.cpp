#include "rotate.h"
#include "matrix.h"

using namespace Geom;

Point Geom::operator*(Point const &v, Rotate const &r) {
    return Point(r.vec[X] * v[X] - r.vec[Y] * v[Y],
                 r.vec[Y] * v[X] + r.vec[X] * v[Y]);
}

Rotate &Rotate::operator*=(Rotate const &b) {
    *this = *this * b;
    return *this;
}

//TODO: cleanup or remove
/*
Rotate rotate_degrees(double degrees)
{
    if (degrees < 0) {
        //TODO: this is incorrect, no?
        return rotate_degrees(-degrees).inverse();
    }

    double const degrees0 = degrees;
    if (degrees >= 360) {
        degrees = fmod(degrees, 360);
    }

    Rotate ret(1., 0.);

    if (degrees >= 180) {
        Rotate const rot180(-1., 0.);
        degrees -= 180;
        ret = rot180;
    }

    if (degrees >= 90) {
        Rotate const rot90(0., 1.);
        degrees -= 90;
        ret *= rot90;
    }

    if (degrees == 45) {
        Rotate const rot45(M_SQRT1_2, M_SQRT1_2);
        ret *= rot45;
    } else {
        ret *= Rotate(M_PI * ( degrees / 180 ));
    }

    Rotate const raw_ret( M_PI * ( degrees0 / 180 ) );
    g_return_val_if_fail(rotate_equalp(ret, raw_ret, 1e-8),
                         raw_ret);
    return ret;
}*/
