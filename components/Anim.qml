pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config

NumberAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    duration: {
        if (type < Anim.StandardSmall || type > Anim.SlowEffects)
            return Tokens.anim.durations.normal;

        if (type === Anim.FastSpatial)
            return Tokens.anim.durations.expressiveFastSpatial;
        if (type === Anim.DefaultSpatial)
            return Tokens.anim.durations.expressiveDefaultSpatial;
        if (type === Anim.SlowSpatial)
            return Tokens.anim.durations.expressiveSlowSpatial;
        if (type === Anim.FastEffects)
            return Tokens.anim.durations.expressiveFastEffects;
        if (type === Anim.DefaultEffects)
            return Tokens.anim.durations.expressiveDefaultEffects;
        if (type === Anim.SlowEffects)
            return Tokens.anim.durations.expressiveSlowEffects;

        const types = ["small", "normal", "large", "extraLarge"];
        const idx = type % 4; // 0-7 are the 4 standard types
        return Tokens.anim.durations[types[idx]];
    }
    easing: {
        if (type === Anim.FastSpatial)
            return Tokens.anim.expressiveFastSpatial ?? Easing.OutCubic;
        if (type === Anim.DefaultSpatial)
            return Tokens.anim.expressiveDefaultSpatial ?? Easing.OutCubic;
        if (type === Anim.SlowSpatial)
            return Tokens.anim.expressiveSlowSpatial ?? Easing.OutCubic;
        if (type === Anim.FastEffects)
            return Tokens.anim.expressiveFastEffects ?? Easing.Linear;
        if (type === Anim.DefaultEffects)
            return Tokens.anim.expressiveDefaultEffects ?? Easing.InOutQuad;
        if (type === Anim.SlowEffects)
            return Tokens.anim.expressiveSlowEffects ?? Easing.InOutQuad;

        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return Tokens.anim.emphasized ?? Easing.InOutBack;

        const types = ["standardSmall", "standard", "standardLarge", "standardExtraLarge"];
        const idx = type % 4; // 0-11 are the 3 standard types
        return Tokens.anim[types[idx]] ?? Easing.InOutQuad;
    }
}
