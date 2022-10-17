FROM nvidia/cuda:10.0-cudnn7-devel-ubuntu18.04

# Disable interaction with tzinf, which asks for your geographic region
ENV DEBIAN_FRONTEND=noninteractive

# Declare some ARGuments
ARG PYTHON_VERSION=3.6
ARG CONDA_VERSION=3
ARG CONDA_PY_VERSION=4.5.11

# update repos and get packages
RUN apt-get update && \
    apt-get install -y — no-install-recommends python3-pip python3-dev git ssh wget \
    cmake libgoogle-glog-dev libatlas-base-dev libopencv-dev \
    libboost-all-dev libeigen3-dev libsuitesparse-dev libgtk2.0-dev libsm6 libxext6 \
    unzip python3-pyqt5 kate geeqie firefox python3-tk \
    bzip2 libopenblas-dev pbzip2 libgl1-mesa-glx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
    
# INSTALLATION OF CONDA
ENV PATH /opt/conda/bin:$PATH

RUN wget — quiet https://repo.anaconda.com/miniconda/Miniconda$ CONDA_VERSION-$ CONDA_PY_VERSION-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda clean -tipsy && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo “. /opt/conda/etc/profile.d/conda.sh” >> ~/.bashrc && \
    echo “conda activate base” >> ~/.bashrc

ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Create a conda environment to use the Freipose
RUN conda update -n base -c defaults conda && \
    conda create -y -n freipose python=3.6 Pillow==6.0.0 scipy==1.2.1 \
    matplotlib==3.0.3 Cython tqdm pandas numpy==1.16.4 tensorflow-gpu==1.13.1 joblib

# Activate the conda environment
RUN conda activate freipose && \
    pip3 install opencv-python==4.1.2.30 pyx commentjson colored tensorpack==0.9.4

# You can add the new created environment to the path
ENV PATH /opt/conda/envs/freipose/bin:$PATH

#RUN pip3 install --upgrade pip
#RUN pip3 install Pillow==6.0.0 scipy==1.2.1 opencv-python==4.1.2.30 matplotlib==3.0.3 Cython pyx commentjson tqdm pandas numpy==1.16.4 tensorflow-gpu==1.13.1 joblib colored tensorpack==0.9.4

## Container's mount point for the host's input/output folder
VOLUME "/host"

## Enable X in the container
ARG DISPLAY
ENV XAUTHORITY $XAUTHORITY

## Setup "machine id" used by DBus for proper (complaint-free) X usage
ARG machine_id
ENV machine_id=${machine_id}
RUN sudo chmod o+w /etc/machine-id &&       \
    echo ${machine_id} > /etc/machine-id && \
sudo chmod o-w /etc/machine-id

## Switch to non-root user
ARG uid
ARG gid
ARG username
ENV uid=${uid}
ENV gid=${gid}
ENV USER=${username}
RUN groupadd -g $gid $USER &&                                         \
    mkdir -p /home/$USER &&                                           \
    echo "${USER}:x:${uid}:${gid}:${USER},,,:/home/${USER}:/bin/bash" \
         >> /etc/passwd &&                                            \
    echo "${USER}:x:${uid}:"                                          \
         >> /etc/group &&                                             \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL"                            \
         > /etc/sudoers.d/${USER} &&                                  \
    chmod 0440 /etc/sudoers.d/${USER} &&                              \
    chown ${uid}:${gid} -R /home/${USER}

USER ${USER}
ENV HOME=/home/${USER}

WORKDIR ${HOME}

## make python3 default
RUN sudo rm -f /usr/bin/python && sudo ln -s /usr/bin/python3 /usr/bin/python

## install cocotools
RUN cd ~ && git clone https://github.com/cocodataset/cocoapi && cd cocoapi/PythonAPI/ && sudo make install

# install FreiPose
RUN cd ~ && git clone https://github.com/lmb-freiburg/FreiPose.git && cd FreiPose && ln -s /host/ ./data && \
    ln -s /host/trainings ./trainings && \
    cd utils/triangulate/ && python setup.py build_ext --inplace

## Download network weights
RUN cd ~/FreiPose/ && wget --no-check-certificate https://lmb.informatik.uni-freiburg.de/data/RatTrack/data/weights.zip && unzip weights.zip && rm weights.zip

# hack needed to make computer with more than one GPU work if the first one is not cuda compatible
ENV CUDA_VISIBLE_DEVICES="0" 
