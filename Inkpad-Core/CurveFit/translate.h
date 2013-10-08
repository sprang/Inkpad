#ifndef SEEN_Geom_TRANSLATE_H
#define SEEN_Geom_TRANSLATE_H

#include "point.h"

namespace Geom {

class Translate {
  public:
    Point offset;  //TODO: Should this be public? Perhaps these classes should have accessors
  private:
    Translate();  //No blank constructor
  public:
    explicit Translate(Point const &p) : offset(p) {}
    explicit Translate(Coord const x, Coord const y) : offset(x, y) {}
    inline Coord operator[](Dim2 const dim) const { return offset[dim]; }
    inline Coord operator[](unsigned const dim) const { return offset[dim]; }
    inline bool operator==(Translate const &o) const { return offset == o.offset; }
    inline bool operator!=(Translate const &o) const { return offset != o.offset; }
};

inline Point operator*(Point const &v, Translate const &t) { return v + t.offset; }
inline Point operator/(Point const &v, Translate const &t) { return v - t.offset; }
inline Translate operator*(Translate const &a, Translate const &b) { return Translate( a.offset + b.offset ); }
inline Translate operator/(Translate const &a, Translate const &b) { return Translate( a.offset - b.offset ); }

} /* namespace Geom */


#endif /* !SEEN_Geom_TRANSLATE_H */

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
