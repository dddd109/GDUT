fid=open('txt3.txt','r');
n1=6;n2=3;
a=[];
for i=1:n1
    tmp=str2num(fgetl(fid));
    a=[a,tmp];
end
for i=1:n1
    str1=char(['b',int2str(i),'=[];']);


