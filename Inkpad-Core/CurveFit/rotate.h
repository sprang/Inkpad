#ifndef SEEN_Geom_ROTATE_H
#define SEEN_Geom_ROTATE_H

/** \file
 * Rotation about the origin.
 */

#include "point.h"
#include <cmath>

namespace Geom {

/** Notionally an Geom::Matrix corresponding to rotation about the origin.
    Behaves like Geom::Matrix for multiplication.
**/
class Rotate {
  public:
    Point vec;

  private:
    Rotate();

  public:
   /** Constructs a Rotate transformation corresponding to an angle.
    * \param theta the rotation angle in radians about the origin
    *
    * \see Geom::Rotate_degrees
    *
    * Angle direction in Inkscape code: If you use the traditional mathematics convention that y
    * increases upwards, then positive angles are anticlockwise as per the mathematics convention.  If
    * you take the common non-mathematical convention that y increases downwards, then positive angles
    * are clockwise, as is common outside of mathematics.
    */
    explicit Rotate(Coord const theta) : vec(std::cos(theta), std::sin(theta)) {}
    explicit Rotate(Point const &p) : vec(p) {}
    explicit Rotate(Coord const x, Coord const y) : vec(x, y) {}

    inline bool operator==(Rotate const &o) const { return vec == o.vec; }
    inline bool operator!=(Rotate const &o) const { return vec != o.vec; }

    Rotate &operator*=(Rotate const &b);
    /* Defined in Rotate-ops.h. */

    Rotate inverse() const {
        /** \todo
         * In the usual case that vec is a unit vector (within rounding error),
         * dividing by len_sq is either a noop or numerically harmful. 
         * Make a unit_Rotate class (or the like) that knows its length is 1.
         */
        double const len_sq = dot(vec, vec);
        return Rotate( Point(vec[X], -vec[Y])
                       / len_sq );
    }
};

inline bool rotate_equalp(Geom::Rotate const &a, Geom::Rotate const &b, double const eps)
{ return point_equalp(a.vec, b.vec, eps); }

//Rotate rotate_degrees(double degrees);

Point operator*(Point const &v, Rotate const &r);
inline Point operator/(Point const &v, Rotate const &r) { return v * r.inverse(); }
inline Rotate operator*(Rotate const &a, Rotate const &b) { return Rotate( a.vec * b ); }
inline Rotate operator/(Rotate const &a, Rotate const &b) { return a * b.inverse(); }

} /* namespace Geom */


#endif /* !SEEN_Geom_ROTATE_H */

/*
  Local Variables:
  mode:c++
  c-file-style:"stroustrup"
  c-file-offsets:((innamespace . 0)(inline-open . 0)(case-label . +))
  indent-tabs-mode:nil
  fill-column:99
  End:
*/
// vim: filetype=cpp:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=99 :
