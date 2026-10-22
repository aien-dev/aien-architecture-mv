#!/bin/sh
# metrics.sh JOBSLOG SCALE: the comparison numbers from a replay log, in trace minutes.
#   build wait / measure wait: from arrival to the moment the stand-in job started
#   jobs over 20 min: builds + measurements whose wait was over 20 minutes
#   load during measurements: build-minutes that ran inside measurement time, the
#   share of measurement time with at least one build running, and the mean number
#   of builds running then (each real build here is make -j4 to -j8, so 1 build ~ 4-8 load)
awk -v s="${2:-60}" '
  $1=="arrive" {a[$2]=$4; c[$2]=$3}
  $1=="start"  {st[$2]=$4}
  $1=="end"    {en[$2]=$4}
  function med(v, n,   i, j, t) { for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (v[j]<v[i]) {t=v[i]; v[i]=v[j]; v[j]=t}
                                  return n ? (n%2 ? v[(n+1)/2] : (v[n/2]+v[n/2+1])/2) : 0 }
  END {
    nb=nm=over=0; mb=mm=0; never=0
    for (k in a) {
      if (!(k in st)) { never++; continue }
      w=(st[k]-a[k])*s/60000
      if (c[k]=="build") { b[++nb]=w; if (w>mb) mb=w }
      if (c[k]=="measure") { m[++nm]=w; if (w>mm) mm=w }
      if ((c[k]=="build" || c[k]=="measure") && w>20) over++
    }
    # build activity inside measurement run time
    mt=0; ov=0; covered=0
    for (k in st) if (c[k]=="measure" && (k in en)) {
      mt+=en[k]-st[k]
      n=0; delete ev
      for (j in st) if (c[j]=="build" && (j in en)) {
        lo=(st[j]>st[k]?st[j]:st[k]); hi=(en[j]<en[k]?en[j]:en[k])
        if (hi>lo) { ov+=hi-lo; ev[++n]=lo" 1"; ev[++n]=hi" -1" }
      }
      # time with >=1 build running: sweep sorted events
      for (i=1;i<=n;i++) for (j2=i+1;j2<=n;j2++) { split(ev[i],x," "); split(ev[j2],y," "); if (y[1]+0<x[1]+0) {t=ev[i]; ev[i]=ev[j2]; ev[j2]=t} }
      cnt=0; last=0
      for (i=1;i<=n;i++) { split(ev[i],x," "); if (cnt>0) covered+=x[1]-last; cnt+=x[2]; last=x[1] }
    }
    printf "builds: %d   median wait %.1f min   worst %.1f min\n", nb, med(b,nb), mb
    printf "measurements: %d   median wait %.1f min   worst %.1f min\n", nm, med(m,nm), mm
    printf "jobs that waited over 20 min: %d\n", over
    printf "jobs that never started: %d\n", never
    printf "during measurements: %.1f build-minutes ran, at least one build running %.0f%% of measurement time, mean builds running %.2f\n", ov*s/60000, mt?100*covered/mt:0, mt?ov/mt:0
  }' "$1"
